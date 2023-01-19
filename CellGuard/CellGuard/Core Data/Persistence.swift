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
        
        try? assignLocationsToTweakCells()
        
        logger.debug("Successfully inserted \(cells.count) tweak cells.")
    }
    
    /// Uses `NSBatchInsertRequest` (BIR) to import ALS cell properties into the Core Data store on a private queue.
    func importALSCells(from cells: [ALSQueryCell], source: NSManagedObjectID) throws {
        let taskContext = newTaskContext()
        
        taskContext.name = "importContext"
        taskContext.transactionAuthor = "importALSCells"
        
        var success = false
        
        taskContext.performAndWait {
            let importedDate = Date()
            
            // We can't use a BatchInsertRequest because it doesn't support relationships
            // See: https://developer.apple.com/forums/thread/676651
            cells.forEach { queryCell in
                let cell = ALSCell(context: taskContext)
                cell.imported = importedDate
                queryCell.applyTo(alsCell: cell)
                
                if let queryLocation = queryCell.location {
                    let location = ALSLocation(context: taskContext)
                    queryLocation.applyTo(location: location)
                    cell.location = location
                }
            }
            
            // Get the tweak cell managed object from its ID
            guard let tweakCell = try? taskContext.existingObject(with: source) as? TweakCell else {
                self.logger.warning("Can't get tweak cell (\(source)) from its object ID")
                return
            }
            tweakCell.status = CellStatus.verified.rawValue

            // Fetch the verification cell for the tweak cell and assign it
            do {
                let verifyCell = try fetchALSCell(from: tweakCell, context: taskContext)
                if let verifyCell = verifyCell {
                    tweakCell.verification = verifyCell
                } else {
                    self.logger.warning("Can't assign a verification cell for tweak cell: \(tweakCell)")
                    return
                }
            } catch {
                self.logger.warning("Can't execute a fetch request for getting a verfication cell for tweak cell: \(tweakCell)")
                return
            }
            
            // Save the task context
            do {
                try taskContext.save()
                success = true
            } catch {
                self.logger.warning("Can't save tweak cell with successful verification: \(error)")
            }
        }
        
        if !success {
            throw PersistenceError.batchInsertError
        }
        
        logger.debug("Successfully inserted \(cells.count) ALS cells.")

    }
    
    /// Uses `NSBatchInsertRequest` (BIR) to import locations into the Core Data store on a private queue.
    func importUserLocations(from locations: [LDMLocation]) throws {
        let taskContext = newTaskContext()
        
        taskContext.name = "importContext"
        taskContext.transactionAuthor = "importLocations"
        
        var success = false
        
        taskContext.performAndWait {
            var index = 0
            let total = locations.count
            
            let importedDate = Date()
            
            let batchInsertRequest = NSBatchInsertRequest(entity: UserLocation.entity(), managedObjectHandler: { location in
                guard index < total else { return true }
                
                if let location = location as? UserLocation {
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
            logger.warning("Can't to fetch the latest \(count) unverified cells: \(fetchError)")
            throw fetchError
        }
        
        return queryCells
    }
    
    func assignExistingALSIfPossible(to tweakCellID: NSManagedObjectID) throws -> Bool {
        let taskContext = newTaskContext()
        
        taskContext.name = "updateContext"
        taskContext.transactionAuthor = "assignExistingALSIfPossible"
        
        var fetchError: Error?
        var found = false
        
        taskContext.performAndWait {
            do {
                guard let tweakCell = taskContext.object(with: tweakCellID) as? TweakCell else {
                    return
                }
                
                guard let alsCell = try fetchALSCell(from: tweakCell, context: taskContext) else {
                    return
                }
                
                found = true
                
                tweakCell.status = CellStatus.verified.rawValue
                tweakCell.verification = alsCell
                
                try taskContext.save()
            } catch {
                fetchError = error
            }
        }
        
        if let fetchError = fetchError {
            logger.warning(
                "Can't fetch or save for assinging an existing ALS cell to a tweak cell (\(tweakCellID) if possible: \(fetchError)")
            throw fetchError
        }
        
        return found
    }
    
    private func fetchALSCell(from tweakCell: TweakCell, context: NSManagedObjectContext) throws -> ALSCell? {
        let fetchRequest = NSFetchRequest<ALSCell>()
        fetchRequest.entity = ALSCell.entity()
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = sameCellPredicate(cell: tweakCell)
        
        do {
            let result = try fetchRequest.execute()
            return result.first
        } catch {
            self.logger.warning("Can't fetch ALS cell for tweak cell (\(tweakCell)): \(error)")
            throw error
        }
    }
    
    private func queryCell(from cell: TweakCell) -> ALSQueryCell {
        return ALSQueryCell(
            technology: ALSTechnology(rawValue: cell.technology ?? "") ?? .LTE,
            country: cell.country,
            network: cell.network,
            area: cell.area,
            cell: cell.cell
        )
    }
    
    func sameCellPredicate(cell: Cell) -> NSPredicate {
        return NSPredicate(
            format: "technology = %@ and country = %@ and network = %@ and area = %@ and cell = %@",
            cell.technology ?? "", cell.country as NSNumber, cell.network as NSNumber,
            cell.area as NSNumber, cell.cell as NSNumber
        )
    }
    
    func storeCellStatus(cellId: NSManagedObjectID, status: CellStatus) throws {
        let taskContext = newTaskContext()
        
        taskContext.name = "updateContext"
        taskContext.transactionAuthor = "storeCellStatus"
        
        var saveError: Error? = nil
        taskContext.performAndWait {
            if let tweakCell = taskContext.object(with: cellId) as? TweakCell {
                tweakCell.status = status.rawValue
                do {
                    try taskContext.save()
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
        let taskContext = newTaskContext()
        
        taskContext.name = "updateContext"
        taskContext.transactionAuthor = "assignLocationsToTweakCells"
        
        var successful: Int = 0
        var count: Int = 0
        var contextError: Error?
        
        taskContext.performAndWait {
            // Fetch all tweak cells without location
            let cellFetchRequest = NSFetchRequest<TweakCell>()
            cellFetchRequest.entity = TweakCell.entity()
            // TODO: Collected in the last 14 days
            cellFetchRequest.predicate = NSPredicate(format: "location == nil and collected != nil")
            
            let cells: [TweakCell]
            do {
                cells = try cellFetchRequest.execute()
            } catch {
                self.logger.warning("Can't fetch tweak cells without any location: \(error)")
                contextError = error
                return
            }
            
            if cells.isEmpty {
                self.logger.debug("There are no tweak cells without location data")
                return
            }
            count = cells.count
            
            let calendar = Calendar.current
            
            let min = cells.min { $0.collected! < $1.collected! }?.collected
            let max = cells.max { $0.collected! < $1.collected! }?.collected
            
            let minDay = calendar.date(byAdding: .day, value: -1, to: min!)!
            let maxDay = calendar.date(byAdding: .day, value: 1, to: max!)!
            
            // Fetch locations in date range with a margin of one day
            let locationFetchRequest = NSFetchRequest<UserLocation>()
            locationFetchRequest.entity = UserLocation.entity()
            locationFetchRequest.predicate = NSPredicate(format: "import > %@ and imported < %@ and collected != nil", minDay as NSDate, maxDay as NSDate)
            
            let locations: [UserLocation]
            do {
                locations = try locationFetchRequest.execute()
            } catch {
                self.logger.warning("Can't fetch user locations with in \(minDay) - \(maxDay): \(error)")
                contextError = error
                return
            }
            
            if locations.isEmpty {
                self.logger.debug("There no user locations which can be assigned to \(cells.count) tweak cells")
                return
            }
            
            // Assign each tweak cell location with min (tweakCell.collected - location.timestamp) which is greater or equal to zero
            let collectedLocationMap: [Date : UserLocation] = Dictionary(uniqueKeysWithValues: locations.map { ($0.collected!, $0) })
            let collectedDates = collectedLocationMap.keys
            
            cells.forEach { cell in
                let lastLocationBefore = collectedDates
                    .filter { $0 > cell.collected! }
                    .max(by: { $0 < $1 })
                
                // If we've got no location (because it could be older than a day), we'll dont set it
                guard let lastLocationBefore = lastLocationBefore else {
                    return
                }
                
                // If the location is older than a day, we'll skip it
                if cell.collected!.timeIntervalSince(lastLocationBefore) > 60 * 60 * 24 {
                    // TODO: Somehow mark the cell not to scan it again?
                    return
                }
                
                // If not, we'll assign it
                cell.location = collectedLocationMap[lastLocationBefore]
                successful += 1
            }
            
            // Save everything
            do {
                try taskContext.save()
            } catch {
                contextError = error
                self.logger.debug("Can't save context with \(locations.count) locations assigned to \(cells.count) tweak cells: \(error)")
            }
        }
        
        if let contextError = contextError {
            throw contextError
        }
        
        self.logger.debug("Successfully assigned user locations to \(successful) tweak cells of out \(count) cells.")
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
