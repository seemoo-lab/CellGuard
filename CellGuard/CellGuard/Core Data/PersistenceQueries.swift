//
//  PersistenceQueries.swift
//  CellGuard
//
//  Created by Lukas Arnold on 03.02.23.
//

import CoreData

extension PersistenceController {
    
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
                    cell.score = 0
                    cell.nextVerification = Date()
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
            logger.debug("Failed to execute batch import request for tweak cells.")
            throw PersistenceError.batchInsertError
        }
        
        logger.debug("Successfully inserted \(cells.count) tweak cells.")
    }
    
    /// Uses `NSBatchInsertRequest` (BIR) to import ALS cell properties into the Core Data store on a private queue.
    func importALSCells(from cells: [ALSQueryCell], source: NSManagedObjectID) throws {
        // TODO: Add a constraint for technology,country,network,area,cell
        // Apparently this is not possible with parent entities. ):
        // See: https://developer.apple.com/forums/thread/36775
        
        let taskContext = newTaskContext()
        
        taskContext.name = "importContext"
        taskContext.transactionAuthor = "importALSCells"
        
        var success = false
        
        taskContext.performAndWait {
            let importedDate = Date()
            
            // We can't use a BatchInsertRequest because it doesn't support relationships
            // See: https://developer.apple.com/forums/thread/676651
            cells.forEach { queryCell in
                // Don't add the check if it already exists
                let existFetchRequest = NSFetchRequest<ALSCell>()
                existFetchRequest.entity = ALSCell.entity()
                existFetchRequest.predicate = sameCellPredicate(queryCell: queryCell)
                do {
                    // TODO: Update the date of existing cell
                    if try taskContext.count(for: existFetchRequest) > 0 {
                        return
                    }
                } catch {
                    self.logger.warning("Can't check if ALS cells (\(queryCell)) already exists: \(error)")
                    return
                }
                
                // The cell don't exists, so we can add it
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
    
    /// Calculates the distance between the location for the tweak cell and its verified counter part from Apple's database.
    /// If no verification or locations references cell exist, nil is returned.
    func calculateDistance(tweakCell tweakCellID: NSManagedObjectID) -> CellLocationDistance? {
        let taskContext = newTaskContext()
        
        var distance: CellLocationDistance? = nil
        taskContext.performAndWait {
            guard let tweakCell = taskContext.object(with: tweakCellID) as? TweakCell else {
                logger.warning("Can't calculate distance for cell \(tweakCellID): Cell missing from task context")
                return
            }
            
            guard let alsCell = tweakCell.verification else {
                logger.warning("Can't calculate distance for cell \(tweakCellID): No verification ALS cell")
                return
            }
            
            guard let userLocation = tweakCell.location else {
                logger.warning("Can't calculate distance for cell \(tweakCellID): Missing user location from cell")
                return
            }
            
            guard let alsLocation = alsCell.location else {
                logger.warning("Can't calculate distance for cell \(tweakCellID): Missing location from ALS cell")
                return
            }
            
            distance = CellLocationDistance.distance(userLocation: userLocation, alsLocation: alsLocation)
        }
        
        return distance
    }
    
    /// Uses `NSBatchInsertRequest` (BIR) to import locations into the Core Data store on a private queue.
    func importUserLocations(from locations: [TrackedUserLocation]) throws {
        let taskContext = newTaskContext()
        
        taskContext.name = "importContext"
        taskContext.transactionAuthor = "importLocations"
        
        var success = false
        
        // TODO: Only import if the location is different by a margin with the last location
        
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
    
    /// Uses `NSBatchInsertRequest` (BIR) to import QMI packets into the Core Data store on a private queue.
    func importQMIPackets(from packets: [(CPTPacket, ParsedQMIPacket)]) throws {
        let taskContext = newTaskContext()
        
        taskContext.name = "importContext"
        taskContext.transactionAuthor = "importQMIPackets"
        
        var success = false
        
        taskContext.performAndWait {
            var index = 0
            let total = packets.count
            
            let importedDate = Date()
            
            let batchInsertRequest = NSBatchInsertRequest(entity: QMIPacket.entity(), managedObjectHandler: { dbPacket in
                guard index < total else { return true }
                
                if let dbPacket = dbPacket as? QMIPacket {
                    let (tweakPacket, parsedPacket) = packets[index]
                    dbPacket.data = tweakPacket.data
                    dbPacket.collected = tweakPacket.timestamp
                    dbPacket.direction = tweakPacket.direction.rawValue
                    dbPacket.proto = tweakPacket.proto.rawValue
                    
                    dbPacket.service = Int16(parsedPacket.qmuxHeader.serviceId)
                    dbPacket.message = Int32(parsedPacket.messageHeader.messageId)
                    dbPacket.indication = parsedPacket.transactionHeader.indication
                    
                    dbPacket.imported = importedDate
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
            logger.debug("Failed to execute batch import request for QMI packets.")
            throw PersistenceError.batchInsertError
        }
        
        logger.debug("Successfully inserted \(packets.count) tweak QMI packets.")
    }
    
    /// Uses `NSBatchInsertRequest` (BIR) to import ARI packets into the Core Data store on a private queue.
    func importARIPackets(from packets: [(CPTPacket, ParsedARIPacket)]) throws {
        let taskContext = newTaskContext()
        
        taskContext.name = "importContext"
        taskContext.transactionAuthor = "importARIPackets"
        
        var success = false
        
        taskContext.performAndWait {
            var index = 0
            let total = packets.count
            
            let importedDate = Date()
            
            let batchInsertRequest = NSBatchInsertRequest(entity: ARIPacket.entity(), managedObjectHandler: { dbPacket in
                guard index < total else { return true }
                
                if let dbPacket = dbPacket as? ARIPacket {
                    let (tweakPacket, parsedPacket) = packets[index]
                    dbPacket.data = tweakPacket.data
                    dbPacket.collected = tweakPacket.timestamp
                    dbPacket.direction = tweakPacket.direction.rawValue
                    dbPacket.proto = tweakPacket.proto.rawValue
                    
                    dbPacket.group = Int16(parsedPacket.header.group)
                    dbPacket.type = Int32(parsedPacket.header.type)
                    
                    dbPacket.imported = importedDate
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
            logger.debug("Failed to execute batch import request for ARI packets.")
            throw PersistenceError.batchInsertError
        }
        
        logger.debug("Successfully inserted \(packets.count) tweak ARI packets.")
    }
    
    func fetchLatestUnverifiedTweakCells(count: Int) throws -> (NSManagedObjectID, ALSQueryCell, CellStatus?)?  {
        var cell: (NSManagedObjectID, ALSQueryCell, CellStatus?)? = nil
        var fetchError: Error? = nil
        newTaskContext().performAndWait {
            let request = NSFetchRequest<TweakCell>()
            request.entity = TweakCell.entity()
            request.fetchLimit = count
            request.predicate = NSPredicate(format: "status != %@ and nextVerification <= %@", CellStatus.verified.rawValue, Date() as NSDate)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \TweakCell.collected, ascending: false)]
            request.returnsObjectsAsFaults = false
            do {
                let tweakCells = try request.execute()
                if let first = tweakCells.first {
                    cell = (first.objectID, Self.queryCell(from: first), CellStatus(rawValue: first.status ?? ""))
                }
            } catch {
                fetchError = error
            }
        }
        
        if let fetchError = fetchError {
            logger.warning("Can't to fetch the latest \(count) unverified cells: \(fetchError)")
            throw fetchError
        }
        
        return cell
    }
    
    func fetchCellLifespan(of tweakCellID: NSManagedObjectID) throws -> (start: Date, end: Date, after: NSManagedObjectID)? {
        let taskContext = newTaskContext()
        
        var cellTuple: (start: Date, end: Date, after: NSManagedObjectID)? = nil
        var fetchError: Error? = nil
        taskContext.performAndWait {
            guard let tweakCell = taskContext.object(with: tweakCellID) as? TweakCell else {
                logger.warning("Can't convert NSManagedObjectID \(tweakCellID) to TweakCell")
                return
            }
            
            guard let startTimestamp = tweakCell.collected else {
                logger.warning("TweakCell \(tweakCell) has not collected timestamp")
                return
            }
            
            let request = NSFetchRequest<TweakCell>()
            request.entity = TweakCell.entity()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "collected > %@", startTimestamp as NSDate)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \TweakCell.collected, ascending: true)]
            request.returnsObjectsAsFaults = false
            do {
                let tweakCells = try request.execute()
                if let tweakCell = tweakCells.first {
                    if let endTimestamp = tweakCell.collected {
                        cellTuple = (start: startTimestamp, end: endTimestamp, after: tweakCell.objectID)
                    } else {
                        logger.warning("TweakCell \(tweakCell) has not collected timestamp")
                    }
                }
            } catch {
                fetchError = error
            }
        }
        
        if let fetchError = fetchError {
            logger.warning("Can' fetch the first cell after the cell \(tweakCellID): \(fetchError)")
            throw fetchError
        }
        
        return cellTuple
    }
    
    func fetchQMIPackets(direction: CPTDirection, service: Int16, message: Int32, indication: Bool, start: Date, end: Date) throws -> [NSManagedObjectID: ParsedQMIPacket] {
        var packets: [NSManagedObjectID: ParsedQMIPacket] = [:]
        
        var fetchError: Error? = nil
        newTaskContext().performAndWait {
            let request = NSFetchRequest<QMIPacket>()
            request.entity = QMIPacket.entity()
            request.predicate = NSPredicate(
                format: "direction = %@ and service = %@ and message = %@ and indication = %@ and %@ <= collected and collected <= %@",
                direction.rawValue as NSString, service as NSNumber, message as NSNumber, NSNumber(booleanLiteral: indication), start as NSDate, end as NSDate
            )
            request.sortDescriptors = [NSSortDescriptor(keyPath: \QMIPacket.collected, ascending: false)]
            request.returnsObjectsAsFaults = false
            do {
                let qmiPackets = try request.execute()
                for qmiPacket in qmiPackets {
                    guard let data = qmiPacket.data else {
                        logger.warning("Skipping packet \(qmiPacket) as it provides no binary data")
                        continue
                    }
                    packets[qmiPacket.objectID] = try ParsedQMIPacket(nsData: data)
                }
            } catch {
                fetchError = error
            }
        }
        
        if let fetchError = fetchError {
            logger.warning("Can't fetch QMI packets (service=\(service), message=\(message), indication=\(indication)) from \(start) to \(end): \(fetchError)")
            throw fetchError
        }
        
        return packets
    }
    
    func fetchARIPackets(direction: CPTDirection, group: Int16, type: Int32, start: Date, end: Date) throws -> [NSManagedObjectID: ParsedARIPacket] {
        var packets: [NSManagedObjectID: ParsedARIPacket] = [:]
        
        var fetchError: Error? = nil
        newTaskContext().performAndWait {
            let request = NSFetchRequest<ARIPacket>()
            request.entity = ARIPacket.entity()
            request.predicate = NSPredicate(
                format: "direction = %@ and group = %@ and type = %@ and %@ <= collected and collected <= %@",
                direction.rawValue as NSString, group as NSNumber, type as NSNumber, start as NSDate, end as NSDate
            )
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ARIPacket.collected, ascending: false)]
            request.returnsObjectsAsFaults = false
            do {
                let ariPackets = try request.execute()
                for ariPacket in ariPackets {
                    guard let data = ariPacket.data else {
                        logger.warning("Skipping packet \(ariPacket) as it provides no binary data")
                        continue
                    }
                    packets[ariPacket.objectID] = try ParsedARIPacket(data: data)
                }
            } catch {
                fetchError = error
            }
        }
        
        if let fetchError = fetchError {
            logger.warning("Can't fetch ARI packets (group=\(group), type=\(type)) from \(start) to \(end): \(fetchError)")
            throw fetchError
        }
        
        return packets
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

                tweakCell.verification = alsCell
                
                try taskContext.save()
            } catch {
                fetchError = error
            }
        }
        
        if let fetchError = fetchError {
            logger.warning(
                "Can't fetch or save for assigning an existing ALS cell to a tweak cell (\(tweakCellID) if possible: \(fetchError)")
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
    
    static func queryCell(from cell: TweakCell) -> ALSQueryCell {
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
    
    func sameCellPredicate(queryCell cell: ALSQueryCell) -> NSPredicate {
        return NSPredicate(
            format: "technology = %@ and country = %@ and network = %@ and area = %@ and cell = %@",
            cell.technology.rawValue, cell.country as NSNumber, cell.network as NSNumber,
            cell.area as NSNumber, cell.cell as NSNumber
        )
    }
    
    func storeCellStatus(cellId: NSManagedObjectID, status: CellStatus, addToScore: Int16 = 0) throws {
        let taskContext = newTaskContext()
        
        taskContext.name = "updateContext"
        taskContext.transactionAuthor = "storeCellStatus"
        
        var saveError: Error? = nil
        taskContext.performAndWait {
            if let tweakCell = taskContext.object(with: cellId) as? TweakCell {
                tweakCell.status = status.rawValue
                tweakCell.score = tweakCell.score + addToScore
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
    
    func storeVerificationDelay(cellId: NSManagedObjectID, seconds: Int) throws {
        let taskContext = newTaskContext()
        
        var saveError: Error? = nil
        taskContext.performAndWait {
            if let tweakCell = taskContext.object(with: cellId) as? TweakCell {
                tweakCell.nextVerification = Date().addingTimeInterval(Double(seconds))
                do {
                    try taskContext.save()
                } catch {
                    self.logger.warning("Can't save tweak cell (\(tweakCell)) with verification delay of \(seconds)s: \(error)")
                    saveError = error
                }
            } else {
                self.logger.warning("Can't add verification delay of \(seconds)s to the tweak cell with object ID: \(cellId)")
                saveError = PersistenceError.objectIdNotFoundError
            }
        }
        if let saveError = saveError {
            throw saveError
        }
    }
    
    func storeRejectPacket(cellId: NSManagedObjectID, packetId: NSManagedObjectID) throws {
        let taskContext = newTaskContext()
        
        var saveError: Error? = nil
        taskContext.performAndWait {
            if let tweakCell = taskContext.object(with: cellId) as? TweakCell, let packet = taskContext.object(with: packetId) as? Packet {
                tweakCell.rejectPacket = packet
                do {
                    try taskContext.save()
                } catch {
                    self.logger.warning("Can't save tweak cell (\(tweakCell)) with reject packet \(packet): \(error)")
                    saveError = error
                }
            } else {
                self.logger.warning("Can't add reject packet \(packetId) to the tweak cell with object ID: \(cellId)")
                saveError = PersistenceError.objectIdNotFoundError
            }
        }
        if let saveError = saveError {
            throw saveError
        }
    }
    
    func assignLocation(to tweakCellID: NSManagedObjectID) throws -> (Bool, Date?) {
        let taskContext = newTaskContext()
        
        var saveError: Error? = nil
        var foundLocation: Bool = false
        var cellCollected: Date? = nil
        
        taskContext.performAndWait {
            guard let tweakCell = taskContext.object(with: tweakCellID) as? TweakCell else {
                self.logger.warning("Can't assign location to the tweak cell with object ID: \(tweakCellID)")
                saveError = PersistenceError.objectIdNotFoundError
                return
            }
            
            cellCollected = tweakCell.collected
            
            // Find the most precise user location within a four minute window
            let fetchLocationRequest = NSFetchRequest<UserLocation>()
            fetchLocationRequest.entity = UserLocation.entity()
            fetchLocationRequest.fetchLimit = 1
            fetchLocationRequest.predicate = NSPredicate(
                format: "%@ >= collected and collected <= %@",
                Date().addingTimeInterval(120) as NSDate, Date().addingTimeInterval(120) as NSDate
            )
            fetchLocationRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \UserLocation.horizontalAccuracy, ascending: true)
            ]
            
            // Execute the fetch request
            let locations: [UserLocation]
            do {
                locations = try fetchLocationRequest.execute()
            } catch {
                self.logger.warning("Can't query location for tweak cell \(tweakCell): \(error)")
                saveError = error
                return
            }
            
            // Return with foundLocation = false if we've found no location matching the criteria
            guard let location = locations.first else {
                return
            }
            
            // We've found a location, assign it to the cell, and save the cel
            foundLocation = true
            tweakCell.location = location
            
            do {
                try taskContext.save()
            } catch {
                self.logger.warning("Can't save tweak cell (\(tweakCell)) with an assigned location: \(error)")
                saveError = error
                return
            }
        }
        if let saveError = saveError {
            throw saveError
        }
        
        return (foundLocation, cellCollected)
    }
    
    func countPacketsByType(completion: @escaping (Result<(Int, Int), Error>) -> Void) {
        let backgroundContext = newTaskContext()
        backgroundContext.perform {
            let qmiRequest = NSFetchRequest<QMIPacket>()
            qmiRequest.entity = QMIPacket.entity()
            
            let ariRequest = NSFetchRequest<ARIPacket>()
            ariRequest.entity = ARIPacket.entity()
            
            let result = Result {
                let qmiCount = try backgroundContext.count(for: qmiRequest)
                let ariCount = try backgroundContext.count(for: ariRequest)
                
                return (qmiCount, ariCount)
            }
            
            // Call the callback on the main queue
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    func deletePacketsOlderThan(days: Int) {
        let taskContext = newTaskContext()
        logger.debug("Start deleting packets older than \(days) day(s) from the store...")
        
        taskContext.performAndWait {
            do {
                let startOfDay = Calendar.current.startOfDay(for: Date())
                guard let daysAgo = Calendar.current.date(byAdding: .day, value: -days, to: startOfDay) else {
                    logger.debug("Can't calculate the date for packet deletion")
                    return
                }
                logger.debug("Deleting packets older than \(startOfDay)")
                let predicate = NSPredicate(format: "collected < %@", daysAgo as NSDate)
                
                try deleteData(entity: QMIPacket.entity(), predicate: predicate, context: taskContext)
                try deleteData(entity: ARIPacket.entity(), predicate: predicate, context: taskContext)
                logger.debug("Successfully deleted old packets")
            } catch {
                self.logger.warning("Failed to delete old packets: \(error)")
            }
        }
        
    }
    
    func deleteDataInBackground(categories: [PersistenceCategory], completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Perform the deletion
            let result = Result { try self.deleteData(categories: categories) }
            
            // Call the callback on the main queue
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    /// Synchronously deletes all records in the Core Data store.
    private func deleteData(categories: [PersistenceCategory]) throws {
        let taskContext = newTaskContext()
        logger.debug("Start deleting data of \(categories) from the store...")
        
        // If the ALS cell cache or older locations are deleted but no connected cells, we do not reset their verification status to trigger a re-verification.
        let categoryEntityMapping: [PersistenceCategory: [NSEntityDescription]] = [
            .connectedCells: [TweakCell.entity()],
            .alsCells: [ALSCell.entity(), ALSLocation.entity()],
            .locations: [UserLocation.entity()],
            .packets: [ARIPacket.entity(), QMIPacket.entity()]
        ]
        
        var deleteError: Error? = nil
        taskContext.performAndWait {
            do {
                try categoryEntityMapping
                    .filter { categories.contains($0.key) }
                    .flatMap { $0.value }
                    .forEach { entity in
                        try deleteData(entity: entity, predicate: nil, context: taskContext)
                    }
            } catch {
                self.logger.warning("Failed to delete data: \(error)")
                deleteError = error
            }
            
            logger.debug("Successfully deleted data of \(categories).")
        }
        
        if let deleteError = deleteError {
            throw deleteError
        }
        
        cleanPersistentHistoryChanges()
    }
    
    /// Deletes all records belonging to a given entity
    private func deleteData(entity: NSEntityDescription, predicate: NSPredicate?, context: NSManagedObjectContext) throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
        fetchRequest.entity = entity
        if let predicate = predicate {
            fetchRequest.predicate = predicate
        }
        
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        try context.persistentStoreCoordinator?.execute(deleteRequest, with: context)
    }
    
}
