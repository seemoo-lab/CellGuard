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
    
    // https://developer.apple.com/documentation/swiftui/loading_and_displaying_a_large_data_feed
    // WWDC 2019: https://developer.apple.com/videos/play/wwdc2019/230/
    // WWDC 2020: https://developer.apple.com/videos/play/wwdc2020/10017/
    // WWDC 2021: https://developer.apple.com/videos/play/wwdc2021/10017/
    
    // TODO: Add a lot of comments
    
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: PersistenceController.self)
    )
    
    /// A shared persistence provider to use within the main app bundle.
    static let shared = PersistenceController()

    /// A persistence provider to use with canvas previews.
    static var preview = persistencePreview()

    private let inMemory: Bool
    private var notificationToken: NSObjectProtocol?

    init(inMemory: Bool = false) {
        self.inMemory = inMemory
        
        notificationToken = NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: nil) { note in
            self.logger.debug("Received a persistent store remote change notification.")
            Task {
                self.fetchPersistentHistory()
            }
        }
    }
    
    deinit {
        if let observer = notificationToken {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    /// A persistent history token used for fetching transactions from the store.
    private var lastToken: NSPersistentHistoryToken?
    
    /// A persistent container to set up the Core Data stack
    lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "CellGuard")
        
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        
        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Enable persistent store remote change notification
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        // Enable persistent history tracking
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        // We refresh the UI by consuming store changes via persistent history tracking
        container.viewContext.automaticallyMergesChangesFromParent = false
        container.viewContext.name = "viewContext"
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
        
        return container
    }()
    
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
    
    func importCells(from cells: [CCTCellProperties]) throws {
        let taskContext = newTaskContext()
        
        taskContext.name = "importContext"
        taskContext.transactionAuthor = "importCells"
        
        var success = false
        
        taskContext.performAndWait {
            let source = CellSource(context: taskContext)
            source.type = CellSourceType.tweak.rawValue
            source.timestamp = Date()
            
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
    
    
    func assignLocations() throws {
        // TODO: Implement
    }
    
    /// Synchronously deletes all records in the Core Data store.
    func deleteAllData() {
        let viewContext = container.viewContext
        logger.debug("Start deleting all data from the store...")
        
        viewContext.perform {
            // TODO: Delete all data
        }
        
        logger.debug("Successfully deleted data.")
    }
    
    func fetchPersistentHistory() {
        do {
            try fetchPersistentHistoryTransactionsAndChanges()
        } catch {
            logger.warning("Failed to fetch persistent history: \(error.localizedDescription)")
        }
    }
    
    func fetchPersistentHistoryTransactionsAndChanges() throws {
        let taskContext = newTaskContext()
        taskContext.name = "persistentHistoryContext"
        logger.debug("Start fetching persistent history changes from the store...")
        
        var taskError: Error? = nil
        
        taskContext.performAndWait {
            do {
                let changeRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: self.lastToken)
                let historyResult = try taskContext.execute(changeRequest) as? NSPersistentHistoryResult
                if let history = historyResult?.result as? [NSPersistentHistoryTransaction],
                    !history.isEmpty {
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
    
    func mergePersistentHistoryChanges(from history: [NSPersistentHistoryTransaction]) {
        logger.debug("Received \(history.count) persistent history transactions.")
        
        // Update view context with objectIDs from history change request.
        let viewContext = container.viewContext
        viewContext.perform {
            for transaction in history {
                viewContext.mergeChanges(fromContextDidSave: transaction.objectIDNotification())
                self.lastToken = transaction.token
            }
        }
    }
}
