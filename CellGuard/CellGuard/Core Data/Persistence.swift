//
//  Persistence.swift
//  CellGuard
//
//  Created by Lukas Arnold on 01.01.23.
//

import CoreData
import OSLog

protocol Persistable {
    func asDictionary() -> [String: Any]
}

class PersistenceController {
    
    // Learn more about Core Data and our approach of synchronizing data across multiple queues:
    // https://developer.apple.com/documentation/swiftui/loading_and_displaying_a_large_data_feed
    // WWDC 2019: https://developer.apple.com/videos/play/wwdc2019/230/
    // WWDC 2020: https://developer.apple.com/videos/play/wwdc2020/10017/
    // WWDC 2021: https://developer.apple.com/videos/play/wwdc2021/10017/
    
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: PersistenceController.self)
    )
    
    /// A shared persistence provider to use within the main app bundle.
    static let shared = PersistenceController()

    /// A persistence provider to use with canvas previews.
    static let preview = previewPersistenceController()

    private let inMemory: Bool
    private var notificationToken: NSObjectProtocol?
    
    /// A persistent container to set up the Core Data stack
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        self.inMemory = inMemory
        
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
        
        // Load data from the stores into the container and abort on error
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        // We refresh the UI by consuming store changes via persistent history tracking
        container.viewContext.automaticallyMergesChangesFromParent = false
        container.viewContext.name = "viewContext"
        // If the data is already stored (identified by constraints), we only update the existing properties
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        // We do not use the undo manager therefore we save resources and disable it
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
        
        // We listen for remote store change notification which are sent from other queues.
        notificationToken = NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: nil) { note in
            self.logger.debug("Received a persistent store remote change notification.")
            // Once we receive such notification we update our queue-local history
            Task {
                self.fetchPersistentHistory()
            }
        }
    }
    
    deinit {
        // If set, remove the observer for the remote store change notification
        if let observer = notificationToken {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    /// A persistent history token used for fetching transactions from the store.
    private var lastToken: NSPersistentHistoryToken?
    
    /// Creates and configures a private queue context.
    private func newTaskContext() -> NSManagedObjectContext {
        // Create a preview queue context.
        let taskContext = container.newBackgroundContext()
        taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        // Set unused undoManager to nil for macOS (it is nil by default on iOS)
        // to reduce resource requirements.
        taskContext.undoManager = nil
        return taskContext
    }
    
    // TODO: Import data from Wikipedia
    // MCC -> Country Name
    // MCC, MNC -> Network Operator Name
    
    /// Uses `NSBatchInsertRequest` (BIR) to import cell properties into the Core Data store on a private queue.
    /// All cells are linked to a source with the given type and optional an mcc.
    func importCells(from cells: [CCTCellProperties], sourceType: CellSourceType, mcc: Int32 = 0) throws {
        let taskContext = newTaskContext()
        
        taskContext.name = "importContext"
        taskContext.transactionAuthor = "import" + sourceType.rawValue.capitalized
        
        var success = false
        
        taskContext.performAndWait {
            let source = CellSource(context: taskContext)
            source.type = sourceType.rawValue
            source.timestamp = Date()
            source.mcc = mcc
            
            var index = 0
            let total = cells.count
            
            let batchInsertRequest = NSBatchInsertRequest(entity: Cell.entity()) { dictionary in
                guard index < total else { return true }
                dictionary.addEntries(from: cells[index].asDictionary())
                dictionary["source"] = source.objectID
                index += 1
                return false
            }
            if let fetchResult = try? taskContext.execute(batchInsertRequest),
               let batchInsertResuklt = fetchResult as? NSBatchInsertResult {
                success = batchInsertResuklt.result as? Bool ?? false
            }
        }
        
        if !success {
            logger.debug("Failed to execute batch import request for cells.")
            throw PersistenceError.batchInsertError
        }
        
        logger.debug("Successfully inserted \(cells.count) cells.")
    }
    
    /// Uses `NSBatchInsertRequest` (BIR) to import locations into the Core Data store on a private queue.
    func importLocations(from locations: [LDMLocation]) throws {
        let taskContext = newTaskContext()
        
        taskContext.name = "importContext"
        taskContext.transactionAuthor = "importLocations"
        
        var success = false
        
        taskContext.performAndWait {
            var index = 0
            let total = locations.count
            
            let batchInsertRequest = NSBatchInsertRequest(entity: Location.entity()) { dictionary in
                guard index < total else { return true }
                dictionary.addEntries(from: locations[index].asDictionary())
                index += 1
                return false
            }
            if let fetchResult = try? taskContext.execute(batchInsertRequest),
               let batchInsertResuklt = fetchResult as? NSBatchInsertResult {
                success = batchInsertResuklt.result as? Bool ?? false
            }
        }
        
        if !success {
            logger.debug("Failed to execute batch import request for cells.")
            throw PersistenceError.batchInsertError
        }
        
        logger.debug("Successfully inserted \(locations.count) locations.")
    }
    
    
    /// Uses `NSBatchUpdateRequest` (BIR) to assign locations stored in Core Data  to cells on a private queue.
    func assignLocations() throws {
        // TODO: Implement
    }
    
    /// Synchronously deletes all records in the Core Data store.
    func deleteAllData() {
        let viewContext = container.viewContext
        logger.debug("Start deleting all data from the store...")
        
        viewContext.perform {
            // TODO: Delete all data
            // See: https://www.advancedswift.com/batch-delete-everything-core-data-swift/#delete-everything-delete-all-objects-reset-core-data
        }
        
        logger.debug("Successfully deleted data.")
    }
    
    /// Fetches persistent history into the view context.
    func fetchPersistentHistory() {
        do {
            try fetchPersistentHistoryTransactionsAndChanges()
        } catch {
            logger.warning("Failed to fetch persistent history: \(error.localizedDescription)")
        }
    }
    
    /// Fetches persistent history transaction starting from the `lastToken` and merges it into the view context.
    func fetchPersistentHistoryTransactionsAndChanges() throws {
        let taskContext = newTaskContext()
        taskContext.name = "persistentHistoryContext"
        logger.debug("Start fetching persistent history changes from the store...")
        
        var taskError: Error? = nil
        
        taskContext.performAndWait {
            do {
                // Request transactions that happend since the lastToken
                let changeRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: self.lastToken)
                let historyResult = try taskContext.execute(changeRequest) as? NSPersistentHistoryResult
                if let history = historyResult?.result as? [NSPersistentHistoryTransaction],
                    !history.isEmpty {
                        // If successful, merge them into the view context
                        self.mergePersistentHistoryChanges(from: history)
                        return
                }
                
                logger.debug("No persistent history transactions found.")
                throw PersistenceError.persistentHistoryChangeError
            } catch {
                taskError = error
            }
        }
        
        if let error = taskError {
            throw error
        }
    }
    
    /// Merge transaction part of the`history`parameter into the view context.
    func mergePersistentHistoryChanges(from history: [NSPersistentHistoryTransaction]) {
        logger.debug("Received \(history.count) persistent history transactions.")
        
        // Update view context with objectIDs from history change request.
        let viewContext = container.viewContext
        viewContext.perform {
            // Merge every transaction part of the history into the view context
            for transaction in history {
                viewContext.mergeChanges(fromContextDidSave: transaction.objectIDNotification())
                self.lastToken = transaction.token
            }
        }
    }
}
