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
    static let preview = PersistencePreview.controller()

    private let inMemory: Bool
    private var notificationToken: NSObjectProtocol?
    
    /// A persistent container to set up the Core Data stack
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
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
    func newTaskContext() -> NSManagedObjectContext {
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
    
    /// Uses `NSBatchInsertRequest` (BIR) to import tweak cell properties into the Core Data store on a private queue.
    func importCollectedCells(from cells: [CCTCellProperties]) throws {
        let taskContext = newTaskContext()
        
        taskContext.name = "importContext"
        taskContext.transactionAuthor = "importTweakCells"
        
        var success = false
        
        taskContext.performAndWait {
            var index = 0
            let total = cells.count
            
            let importedDate = Date()
            
            let batchInsertRequest = NSBatchInsertRequest(entity: TweakCell.entity(), managedObjectHandler: { cell in
                guard index < total else { return true }
                
                
                if let cell = cell as? TweakCell {
                    cells[index].applyTo(tweakCell: cell)
                    cell.imported = importedDate
                    cell.status = CellStatus.imported.rawValue
                }
                    
                index += 1
                return false
            })
            
            if let fetchResult = try? taskContext.execute(batchInsertRequest),
               let batchInsertResuklt = fetchResult as? NSBatchInsertResult {
                success = batchInsertResuklt.result as? Bool ?? false
            }
        }
        
        if !success {
            logger.debug("Failed to execute batch import request for tweak cells.")
            throw PersistenceError.batchInsertError
        }
        
        logger.debug("Successfully inserted \(cells.count) tweak cells.")
    }
    
    /// Uses `NSBatchInsertRequest` (BIR) to import ALS cell properties into the Core Data store on a private queue.
    func importALSCells(from cells: [ALSQueryCell], source: NSManagedObjectID) throws {
        let taskContext = newTaskContext()
        
        taskContext.name = "importContext"
        taskContext.transactionAuthor = "importALSCells"
        
        var success = false
        
        taskContext.performAndWait {
            var index = 0
            let total = cells.count
            
            let importedDate = Date()
            
            guard let tweakCell = try? taskContext.existingObject(with: source) as? TweakCell else {
                self.logger.warning("Can't get tweak cell (\(source)) from its object ID")
                return
            }
            tweakCell.status = CellStatus.verified.rawValue

            
            let batchInsertRequest = NSBatchInsertRequest(entity: ALSCell.entity(), managedObjectHandler: { cell in
                guard index < total else { return true }
                
                if let cell = cell as? ALSCell {
                    cells[index].applyTo(alsCell: cell)
                    cell.imported = importedDate
                }
                
                index += 1
                return false
            })
            
            if let fetchResult = try? taskContext.execute(batchInsertRequest),
               let batchInsertResult = fetchResult as? NSBatchInsertResult {
                success = batchInsertResult.result as? Bool ?? false
                if !success {
                    return
                }
            }
            
            let verifyFetchRequest = NSFetchRequest<ALSCell>()
            verifyFetchRequest.entity = ALSCell.entity()
            verifyFetchRequest.fetchLimit = 1
            verifyFetchRequest.predicate = NSPredicate(
                format: "technology = %@ and country = %@ and network = %@ and area = %@ and cell = %@",
                tweakCell.technology ?? "" as NSString, tweakCell.country as NSNumber, tweakCell.network as NSNumber,
                tweakCell.area as NSNumber, tweakCell.cell as NSNumber)
            
            do {
                let verifyCells = try verifyFetchRequest.execute()
                if let verifyCell = verifyCells.first {
                    tweakCell.verification = verifyCell
                } else {
                    self.logger.warning("Can't assign a verification cell for tweak cell: \(tweakCell)")
                }
            } catch {
                self.logger.warning("Can't execute a fetch request for getting a verfication cell for tweak cell: \(tweakCell)")
            }
            
            if success {
                do {
                    try taskContext.save()
                } catch {
                    success = false
                }
            }
        }
        
        if !success {
            logger.debug("Failed to execute batch import request for ALS cells.")
            throw PersistenceError.batchInsertError
        }
        
        logger.debug("Successfully inserted \(cells.count) ALS cells.")

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
            
            let importedDate = Date()
            
            let batchInsertRequest = NSBatchInsertRequest(entity: Location.entity(), managedObjectHandler: { location in
                guard index < total else { return true }
                
                if let location = location as? Location {
                    locations[index].applyTo(location: location)
                    location.imported = importedDate
                }
                
                index += 1
                return false
            })
            if let fetchResult = try? taskContext.execute(batchInsertRequest),
               let batchInsertResult = fetchResult as? NSBatchInsertResult {
                success = batchInsertResult.result as? Bool ?? false
            }
        }
        
        if !success {
            logger.debug("Failed to execute batch import request for cells.")
            throw PersistenceError.batchInsertError
        }
        
        logger.debug("Successfully inserted \(locations.count) locations.")
    }
    
    func fetchLatestUnverfiedTweakCells(count: Int) throws -> [NSManagedObjectID : ALSQueryCell]  {
        var queryCells: [NSManagedObjectID : ALSQueryCell] = [:]
        var fetchError: Error? = nil
        newTaskContext().performAndWait {
            let request = NSFetchRequest<TweakCell>()
            request.entity = TweakCell.entity()
            request.fetchLimit = count
            request.predicate = NSPredicate(format: "status == %@", CellStatus.imported.rawValue)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \TweakCell.collected, ascending: true)]
            request.returnsObjectsAsFaults = false
            do {
                let tweakCells = try request.execute()
                queryCells = Dictionary(uniqueKeysWithValues: tweakCells.map { ($0.objectID, queryCell(from: $0)) })
            } catch {
                fetchError = error
            }
        }
        
        if let fetchError = fetchError {
            logger.debug("Failed to fetch the latest \(count) unverified cells: \(fetchError)")
            throw fetchError
        }
        
        return queryCells
    }
    
    private func queryCell(from cell: TweakCell) -> ALSQueryCell {
        let technology = ALSTechnology(rawValue: cell.technology ?? "LTE") ?? .LTE
        
        return ALSQueryCell(
            technology: technology,
            country: cell.country,
            network: cell.network,
            area: cell.area,
            cell: cell.cell
        )
    }
    
    func storeCellStatus(cellId: NSManagedObjectID, status: CellStatus) throws {
        let context = newTaskContext()
        var saveError: Error? = nil
        context.performAndWait {
            if let tweakCell = context.object(with: cellId) as? TweakCell {
                tweakCell.status = status.rawValue
                do {
                    try context.save()
                } catch {
                    self.logger.warning("Can't save tweak cell (\(tweakCell)) with status == \(status.rawValue): \(error)")
                    saveError = error
                }
            } else {
                self.logger.warning("Can't apply status == \(status.rawValue) to tweak cell with object ID: \(cellId)")
                saveError = PersistenceError.objectIdNotFoundError
            }
        }
        
        if let saveError = saveError {
            throw saveError
        }
    }

    
    
    /// Uses `NSBatchUpdateRequest` (BIR) to assign locations stored in Core Data  to cells on a private queue.
    func assignLocationsToTweakCells() throws {
        // TODO: Implement
        
        // Fetch all tweak cells without location
        
        // Fetch locations in date range
        
        // Assign each tweak cell location with min (tweakCell.collected - location.timestamp) which is greater or equal to zero
        
        // Save everything
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
                
                // This is normal at the first start of the app and doesn't require an exception
                logger.debug("No persistent history transactions found.")
                // throw PersistenceError.persistentHistoryChangeError
                return
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
