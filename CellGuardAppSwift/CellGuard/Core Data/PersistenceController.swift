//
//  Persistence.swift
//  CellGuard
//
//  Created by Lukas Arnold on 01.01.23.
//

import CoreData
import OSLog

// TODO: Maybe use later
protocol Persistable<T> {
    associatedtype T

    func applyTo(_ object: T)
}

extension UserDefaults {

    // See: https://stackoverflow.com/a/49276809

    func historyToken(forKey key: String) throws -> NSPersistentHistoryToken? {
        guard let data = data(forKey: key) else {
            return nil
        }

        return try NSKeyedUnarchiver.unarchivedObject(
            ofClass: NSPersistentHistoryToken.self,
            from: data
        )
    }

    func set(_ value: NSPersistentHistoryToken, forKey key: String) throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true)
        set(data, forKey: key)
    }

}

class PersistenceController {

    // Learn more about Core Data and our approach of synchronizing data across multiple queues:
    // https://developer.apple.com/documentation/swiftui/loading_and_displaying_a_large_data_feed
    // WWDC 2019: https://developer.apple.com/videos/play/wwdc2019/230/
    // WWDC 2020: https://developer.apple.com/videos/play/wwdc2020/10017/
    // WWDC 2021: https://developer.apple.com/videos/play/wwdc2021/10017/

    // Apple didn't mention that the transaction history can deleted.
    // This is important for our use case as we quickly generate a lot of history that can slow down the app.
    // See: https://www.avanderlee.com/swift/persistent-history-tracking-core-data/

    /// A shared persistence provider to use within the main app bundle.
    static let shared = PersistenceController()

    /// A persistence provider to use with canvas previews.
    static let preview = PersistenceController(inMemory: true)

    static func basedOnEnvironment() -> PersistenceController {
        if PreviewInfo.active() {
            return Self.preview
        } else {
            return Self.shared
        }
    }

    /// A persistent container to set up the Core Data stack
    let container: NSPersistentContainer

    let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: PersistenceController.self)
    )

    private let inMemory: Bool
    private var notificationToken: NSObjectProtocol?

    // Provide synchronized access to the lastToken variable
    // See: https://stackoverflow.com/a/65849172
    private let lastTokenLock = NSLock()
    // A persistent history token used for fetching transactions from the store.
    private var _lastToken: NSPersistentHistoryToken?
    private var lastToken: NSPersistentHistoryToken? {
        get {
            lastTokenLock.lock()
            defer { lastTokenLock.unlock() }
            return _lastToken
        }
        set {
            lastTokenLock.lock()
            defer { lastTokenLock.unlock() }
            _lastToken = newValue
        }
    }
    private let lastTokenUserDefaultsKey = "persistence-last-token"

    private init(inMemory: Bool = false) {
        self.inMemory = inMemory

        // It's better to directly initialize the container instead of using a lazy variable
        // Create a persistent container responsible for storing the data on disk
        container = NSPersistentContainer(name: "CellGuard")

        // Check if it has a store description
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }

        // If in memory is set, do not save the container on disk, just in memory
        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }

        // Enable persistent store remote change notification for sending notification between queues
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        // Enable persistent history tracking which keeps track of changes in the Core Data store
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        logger.info("Got description for persistent store")

        // Load data from the stores into the container and abort on error
        self.container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        logger.info("Finished loading persistent stores")

        // It's very important that these modification to the viewContext are performed on the main queue,
        // i.e. that the PersistenceController is initialized on the main queue.
        // Otherwise, both (initializing & main) queues / threads block each other and the app never launches!
        // See: https://developer.apple.com/documentation/coredata/nspersistentcontainer/1640622-viewcontext
        // See: https://www.hackingwithswift.com/quick-start/swiftui/how-to-run-code-when-your-app-launches

        // We refresh the UI by consuming store changes via persistent history tracking
        self.container.viewContext.automaticallyMergesChangesFromParent = false
        self.container.viewContext.name = "viewContext"
        // If the data is already stored (identified by constraints), we only update the existing properties
        self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        // We do not use the undo manager therefore we save resources and disable it
        self.container.viewContext.undoManager = nil
        self.container.viewContext.shouldDeleteInaccessibleFaults = true
        logger.info("Set view context properties")

        // Read the last token from UserDefaults to speed up the start of the app and prevent unnecessary merges
        do {
            lastToken = try UserDefaults.standard.historyToken(forKey: lastTokenUserDefaultsKey)
        } catch {
            self.logger.warning("Can't fetch last history token from user defaults: \(error)")
        }
        logger.info("Queried last history token")

        // Use a serial dispatch queue for persistent store change notifications
        let queue = DispatchQueue(label: "Persistent Store Remote Change", qos: .utility)
        logger.info("Created dispatch queue")

        // We listen for remote store change notification which are sent from other queues.
        notificationToken = NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: nil) { _ in
            self.logger.debug("Received a persistent store remote change notification.")
            // Once we receive such notification we update our queue-local history
            // It's important to wait until the completion of the block, otherwise the calling might assume that the DB has been updated when it has not. (I guess)
            queue.sync {
                self.fetchPersistentHistory()
            }
        }

        logger.info("Finished adding observer")
    }

    deinit {
        // If set, remove the observer for the remote store change notification
        if let observer = notificationToken {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Creates and configures a private queue context.
    func newTaskContext() -> NSManagedObjectContext {
        // To fix possible issues, we could only write in one background queue
        // See: https://stackoverflow.com/a/42745378

        // Create a preview queue context.
        let taskContext = container.newBackgroundContext()
        taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        // Set unused undoManager to nil for macOS (it is nil by default on iOS)
        // to reduce resource requirements.
        taskContext.undoManager = nil
        return taskContext
    }

    /// Fetches persistent history into the view context.
    func fetchPersistentHistory() {
        // More useful resources:
        // - https://www.avanderlee.com/swift/persistent-history-tracking-core-data/
        do {
            try fetchPersistentHistoryTransactionsAndChanges()
        } catch {
            logger.warning("Failed to fetch persistent history: \(error.localizedDescription)")
        }
    }

    func performAndWait<T>(name: String? = nil, author: String? = nil, task: (NSManagedObjectContext) throws -> T?) throws -> T? {
        let context = newTaskContext()
        if let name = name {
            context.name = name
        }
        if let author = author {
            context.transactionAuthor = author
        }
        context.mergePolicy = NSMergePolicy.rollback

        var collectedError: Error?
        var result: T?

        context.performAndWait {
            do {
                result = try task(context)
            } catch {
                collectedError = error
            }
        }

        if let collectedError = collectedError {
            logger.debug("Failed to execute database operation (\(name ?? "no name"), \(author ?? "no author")): \(collectedError)")
            throw collectedError
        }

        return result
    }

    /// Fetches persistent history transaction starting from the `lastToken` and merges it into the view context.
    func fetchPersistentHistoryTransactionsAndChanges() throws {
        logger.debug("Start fetching persistent history changes from the store...")

        try performAndWait(name: "persistentHistoryContext") { context in
            // Request transactions that happened since the lastToken
            let changeRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: lastToken)
            let historyResult: NSPersistentHistoryResult?
            do {
                // The locking implemented for the accessor of lastToken is important as this is an async task and the variable is set from the view task
                historyResult = try context.execute(changeRequest) as? NSPersistentHistoryResult
            } catch let error as NSError {
                // In rare circumstances, a history token expires, i.e. refers to already purged history, see:
                // https://developer.apple.com/documentation/coredata/1535452-validation_error_codes/nspersistenthistorytokenexpirederror
                // https://developer.apple.com/documentation/coredata/consuming_relevant_store_changes
                if error.code == NSPersistentHistoryTokenExpiredError {
                    logger.info("Recovering from an expired history token...")

                    // In those cases, reset the history token
                    lastToken = nil
                    UserDefaults.standard.removeObject(forKey: lastTokenUserDefaultsKey)

                    // and fetch the history from the beginning (and hope that it works)
                    let backupChangeRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: nil as NSPersistentHistoryToken?)
                    historyResult = try context.execute(backupChangeRequest) as? NSPersistentHistoryResult

                    logger.info("Recovery from expired history token successful")
                } else {
                    // If we don't know the error we just re-throw it
                    throw error
                }
            }

            if let history = historyResult?.result as? [NSPersistentHistoryTransaction],
               !history.isEmpty {
                // If successful, merge them into the view context
                self.mergePersistentHistoryChanges(from: history)
            } else {
                // This is normal at the first start of the app and doesn't require an exception
                logger.debug("No persistent history transactions found.")
                // throw PersistenceError.persistentHistoryChangeError
                // But we have to release the lock
            }
        }
    }

    /// Merge transaction part of the`history` parameter into the view context.
    private func mergePersistentHistoryChanges(from history: [NSPersistentHistoryTransaction]) {
        logger.debug("Received \(history.count) persistent history transactions.")

        // Update view context with objectIDs from history change request.
        let viewContext = container.viewContext
        viewContext.performAndWait {
            // Merge every transaction part of the history into the view context
            for transaction in history {
                viewContext.mergeChanges(fromContextDidSave: transaction.objectIDNotification())
            }
            // Only set the token once after every transaction to reduce the number of lock requests
            if let lastToken = history.last?.token {
                self.lastToken = lastToken
            }
        }

        if let token = history.last?.token {
            do {
                try UserDefaults.standard.set(token, forKey: lastTokenUserDefaultsKey)
            } catch {
                logger.warning("Can't save the last history token to user defaults: \(error)")
            }
        }
    }

    func cleanPersistentHistoryChanges() {
        // See: https://www.avanderlee.com/swift/persistent-history-tracking-core-data/

        try? performAndWait(name: "cleanPersistentHistoryChanges") { context in
            guard let token = self.lastToken else {
                logger.debug("No persistent history to delete as we've got no token")
                return
            }

            let deleteHistoryRequest = NSPersistentHistoryChangeRequest.deleteHistory(before: token)
            logger.debug("Deleting persistent history before the token \(token)")
            let result = try context.execute(deleteHistoryRequest)
            logger.debug("Result of deletion: \(result)")
        }
    }

    /// Returns the size in bytes of CellGuard's data store
    func size() -> UInt64 {
        if self.inMemory {
            return 0
        }

        return container.persistentStoreCoordinator.persistentStores.flatMap { store in
            guard let url = store.url else {
                return [] as [String]
            }

            // We only check URLs referencing files on disk, not those in-memory
            if url.scheme != "file" {
                return [] as [String]
            }

            let path = url.path
            // Include the size of SQLite database and its journal files
            // See: https://stackoverflow.com/a/24373470
            return [path, "\(path)-wal", "\(path)-shm"]
        }.map { path in
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: path)
                return attributes[.size] as? UInt64 ?? UInt64(0)
            } catch {
                logger.debug("Can't get attributes for path \(path): \(error)")
            }
            return UInt64(0)
        }.reduce(0, { $0 + $1 })
    }
}
