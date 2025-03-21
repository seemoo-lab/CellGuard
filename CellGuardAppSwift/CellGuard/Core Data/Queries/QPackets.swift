//
//  Packets.swift
//  CellGuard
//
//  Created by Lukas Arnold on 04.05.24.
//

import CoreData
import Foundation

extension PersistenceController {
    
    /// Uses `NSBatchInsertRequest` (BIR) to import QMI packets into the Core Data store on a private queue.
    /// Returns the number of imported packets and references to packets that contain cell information.
    func importQMIPackets(from packets: [(CPTPacket, ParsedQMIPacket)]) throws -> (Int, [NSManagedObjectID]) {
        if packets.isEmpty {
            return (0, [])
        }
        
        let objectIds: [NSManagedObjectID] = try performAndWait(name: "importContext", author: "importQMIPackets") { context in
            var index = 0
            let total = packets.count
            let importedDate = Date()
            
            let batchInsertRequest = NSBatchInsertRequest(entity: PacketQMI.entity(), managedObjectHandler: { dbPacket in
                guard index < total else { return true }
                
                if let dbPacket = dbPacket as? PacketQMI {
                    let (tweakPacket, parsedPacket) = packets[index]
                    dbPacket.data = tweakPacket.data
                    dbPacket.collected = tweakPacket.timestamp
                    dbPacket.direction = tweakPacket.direction.rawValue
                    // dbPacket.proto = tweakPacket.proto.rawValue
                    dbPacket.simSlotID = tweakPacket.simSlotID != nil ? Int16(tweakPacket.simSlotID!) : 0
                    
                    dbPacket.service = Int16(parsedPacket.qmuxHeader.serviceId)
                    dbPacket.message = Int32(parsedPacket.messageHeader.messageId)
                    dbPacket.indication = parsedPacket.transactionHeader.indication
                    
                    dbPacket.imported = importedDate
                }
                
                index += 1
                return false
            })
            
            batchInsertRequest.resultType = .objectIDs
            
            guard let fetchResult = try? context.execute(batchInsertRequest),
                  let batchInsertResult = fetchResult as? NSBatchInsertResult else {
                return []
            }
            
            return batchInsertResult.result as? [NSManagedObjectID]
        } ?? []
        
        var cellPackets: [NSManagedObjectID] = []
        try performAndWait(name: "importContext", author: "importQMIPackets") { context in
            var added = false
            for objectId in objectIds {
                guard let qmiPacket = context.object(with: objectId) as? PacketQMI else {
                    continue
                }
                
                if qmiPacket.service == PacketConstants.qmiCellInfoService
                    && qmiPacket.direction == PacketConstants.qmiCellInfoDirection.rawValue
                    && qmiPacket.message == PacketConstants.qmiCellInfoMessage {
                    cellPackets.append(qmiPacket.objectID)
                }
                
                if qmiPacket.indication == PacketConstants.qmiRejectIndication
                    && qmiPacket.service == PacketConstants.qmiRejectService
                    && qmiPacket.direction == PacketConstants.qmiRejectDirection.rawValue {
                    
                    if qmiPacket.message == PacketConstants.qmiRejectMessage {
                        let index = PacketIndexQMI(context: context)
                        index.collected = qmiPacket.collected
                        index.reject = true
                        qmiPacket.index = index
                        added = true
                    } else if qmiPacket.message == PacketConstants.qmiSignalMessage {
                        let index = PacketIndexQMI(context: context)
                        index.collected = qmiPacket.collected
                        index.signal = true
                        qmiPacket.index = index
                        added = true
                    }
                }
            }
            
            if added {
                try context.save()
            }
        }
        
        // It can be the case the newly imported data is already in the database
        /* if objectIds.isEmpty {
            logger.debug("Failed to execute batch import request for QMI packets.")
            throw PersistenceError.batchInsertError
        } */
        
        logger.debug("Successfully inserted \(packets.count) tweak QMI packets.")
        return (packets.count, cellPackets)
    }
    
    /// Uses `NSBatchInsertRequest` (BIR) to import ARI packets into the Core Data store on a private queue.
    func importARIPackets(from packets: [(CPTPacket, ParsedARIPacket)]) throws -> (Int, [NSManagedObjectID]) {
        if packets.isEmpty {
            return (0, [])
        }
        
        let objectIds: [NSManagedObjectID] = try performAndWait(name: "importContext", author: "importARIPackets") { context in
            var index = 0
            let total = packets.count
            let importedDate = Date()
            
            let batchInsertRequest = NSBatchInsertRequest(entity: PacketARI.entity(), managedObjectHandler: { dbPacket in
                guard index < total else { return true }
                
                if let dbPacket = dbPacket as? PacketARI {
                    let (tweakPacket, parsedPacket) = packets[index]
                    dbPacket.data = tweakPacket.data
                    dbPacket.collected = tweakPacket.timestamp
                    dbPacket.direction = tweakPacket.direction.rawValue
                    // dbPacket.proto = tweakPacket.proto.rawValue
                    dbPacket.simSlotID = tweakPacket.simSlotID != nil ? Int16(tweakPacket.simSlotID!) : 0
                    
                    dbPacket.group = Int16(parsedPacket.header.group)
                    dbPacket.type = Int32(parsedPacket.header.type)
                    
                    dbPacket.imported = importedDate
                }
                
                index += 1
                return false
            })
            
            batchInsertRequest.resultType = .objectIDs
            
            guard let fetchResult = try? context.execute(batchInsertRequest),
                  let batchInsertResult = fetchResult as? NSBatchInsertResult else {
                return []
            }
            
            return batchInsertResult.result as? [NSManagedObjectID]
        } ?? []
        
        var cellPackets: [NSManagedObjectID] = []
        try performAndWait(name: "importContext", author: "importARIPackets") { context in
            var added = false
            
            // TODO: Can we do that in parallel?
            let ariPackets = objectIds
                .compactMap { context.object(with: $0) as? PacketARI }
                .sorted { $0.collected ?? Date.distantPast < $1.collected ?? Date.distantPast }
            
            for ariPacket in ariPackets {
                if ariPacket.direction == PacketConstants.ariCellInfoDirection.rawValue
                    && ariPacket.group == PacketConstants.ariCellInfoGroup
                    && PacketConstants.ariCellInfoTypes.contains(UInt16(ariPacket.type)) {
                    cellPackets.append(ariPacket.objectID)
                }
                
                if ariPacket.direction == PacketConstants.ariRejectDirection.rawValue {
                    if ariPacket.group == PacketConstants.ariRejectGroup && ariPacket.type == PacketConstants.ariRejectType {
                        let index = PacketIndexARI(context: context)
                        index.reject = true
                        index.collected = ariPacket.collected
                        ariPacket.index = index
                        added = true
                    } else if ariPacket.group == PacketConstants.ariSignalGroup && ariPacket.type == PacketConstants.ariSignalType {
                        let index = PacketIndexARI(context: context)
                        index.signal = true
                        index.collected = ariPacket.collected
                        ariPacket.index = index
                        added = true
                    }
                }
            }
            
            if added {
                try context.save()
            }
        }
        
        /* if objectIds.isEmpty {
            logger.debug("Failed to execute batch import request for ARI packets.")
            throw PersistenceError.batchInsertError
        } */
        
        logger.debug("Successfully inserted \(packets.count) tweak ARI packets.")
        return (packets.count, cellPackets)
    }
    
    func fetchIndexedQMIPackets(start: Date, end: Date, reject: Bool = false, signal: Bool = false) throws -> [NSManagedObjectID: ParsedQMIPacket] {
        return try performAndWait(name: "fetchContext", author: "fetchIndexedQMIPackets") { context in
            let request = PacketIndexQMI.fetchRequest()
            
            request.predicate = NSPredicate(
                format: "reject = %@ and signal = %@ and %@ <= collected and collected <= %@",
                NSNumber(booleanLiteral: reject), NSNumber(booleanLiteral: signal), start as NSDate, end as NSDate
            )
            request.sortDescriptors = [NSSortDescriptor(keyPath: \PacketIndexQMI.collected, ascending: false)]
            request.includesSubentities = true
        
            var packets: [NSManagedObjectID: ParsedQMIPacket] = [:]
            for indexedQMIPacket in try request.execute() {
                guard let packet = indexedQMIPacket.packet else {
                    logger.warning("No QMI packet for indexed packet \(indexedQMIPacket)")
                    continue
                }
                guard let data = packet.data else {
                    logger.warning("Skipping packet \(packet) as it provides no binary data")
                    continue
                }
                
                packets[packet.objectID] = try ParsedQMIPacket(nsData: data)
            }

            return packets
        } ?? [:]
    }
    
    func fetchIndexedARIPackets(start: Date, end: Date, reject: Bool = false, signal: Bool = false) throws -> [NSManagedObjectID: ParsedARIPacket] {
        return try performAndWait(name: "fetchContext", author: "fetchIndexedARIPackets") { context in
            let request = PacketIndexARI.fetchRequest()
            
            request.predicate = NSPredicate(
                format: "reject = %@ and signal = %@ and %@ <= collected and collected <= %@",
                NSNumber(booleanLiteral: reject), NSNumber(booleanLiteral: signal), start as NSDate, end as NSDate
            )
            request.sortDescriptors = [NSSortDescriptor(keyPath: \PacketIndexARI.collected, ascending: false)]
            request.includesSubentities = true
        
            var packets: [NSManagedObjectID: ParsedARIPacket] = [:]
            for indexedARIPacket in try request.execute() {
                guard let packet = indexedARIPacket.packet else {
                    logger.warning("No ARI packet for indexed packet \(indexedARIPacket)")
                    continue
                }
                guard let data = packet.data else {
                    logger.warning("Skipping packet \(packet) as it provides no binary data")
                    continue
                }
                packets[packet.objectID] = try ParsedARIPacket(data: data)
            }

            return packets
        } ?? [:]
    }
    
    /// Fetches QMI packets with the specified properties from Core Data.
    /// Remember to update the fetch index `byQMIPacketPropertiesIndex` when fetching new types of packets, otherwise the query slows down significantly.
    func fetchQMIPackets(start: Date, end: Date, direction: CPTDirection, service: Int16, message: Int32, indication: Bool) throws -> [NSManagedObjectID: ParsedQMIPacket] {
        return try performAndWait(name: "fetchContext", author: "fetchQMIPackets") { context in
            let request = PacketQMI.fetchRequest()
            request.predicate = NSPredicate(
                format: "indication = %@ and service = %@ and message = %@ and %@ <= collected and collected <= %@ and direction = %@",
                NSNumber(booleanLiteral: indication), service as NSNumber, message as NSNumber, start as NSDate, end as NSDate, direction.rawValue as NSString
            )
            request.sortDescriptors = [NSSortDescriptor(keyPath: \PacketQMI.collected, ascending: false)]
            // See: https://stackoverflow.com/a/11165883
            request.propertiesToFetch = ["data"]
            
            var dict: [NSManagedObjectID: ParsedQMIPacket] = [:]
            for qmiPacket in try request.execute() {
                guard let data = qmiPacket.data else {
                    logger.warning("Skipping packet \(qmiPacket) as it provides no binary data")
                    continue
                }
                dict[qmiPacket.objectID] = try ParsedQMIPacket(nsData: data)
            }
            
            return dict
        } ?? [:]
    }
    
    /// Fetches ARI packets with the specified properties from Core Data.
    /// Remember to update the fetch index `byARIPacketPropertiesIndex` when fetching new types of packets, otherwise the query slows down significantly.
    func fetchARIPackets(direction: CPTDirection, group: Int16, type: Int32, start: Date, end: Date) throws -> [NSManagedObjectID : ParsedARIPacket] {
        return try performAndWait(name: "fetchContext", author: "fetchARIPackets") { context in
            let request = NSFetchRequest<PacketARI>()
            request.entity = PacketARI.entity()
            request.predicate = NSPredicate(
                format: "group = %@ and type = %@ and %@ <= collected and collected <= %@ and direction = %@",
                group as NSNumber, type as NSNumber, start as NSDate, end as NSDate, direction.rawValue as NSString
            )
            request.sortDescriptors = [NSSortDescriptor(keyPath: \PacketARI.collected, ascending: false)]
            request.returnsObjectsAsFaults = false
            
            var dict: [NSManagedObjectID: ParsedARIPacket] = [:]
            for ariPacket in try request.execute() {
                guard let data = ariPacket.data else {
                    logger.warning("Skipping packet \(ariPacket) as it provides no binary data")
                    continue
                }
                dict[ariPacket.objectID] = try ParsedARIPacket(data: data)
            }
            return dict
        } ?? [:]
    }
    
    func countPacketsByType(completion: @escaping (Result<(Int, Int), Error>) -> Void) {
        let backgroundContext = newTaskContext()
        backgroundContext.perform {
            let qmiRequest = NSFetchRequest<PacketQMI>()
            qmiRequest.entity = PacketQMI.entity()
            
            let ariRequest = NSFetchRequest<PacketARI>()
            ariRequest.entity = PacketARI.entity()
            
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
        do {
            try performAndWait { context in
                logger.debug("Start deleting packets older than \(days) day(s) from the store...")
                let startOfDay = Calendar.current.startOfDay(for: Date())
                guard let daysAgo = Calendar.current.date(byAdding: .day, value: -days, to: startOfDay) else {
                    logger.debug("Can't calculate the date for packet deletion")
                    return
                }
                logger.debug("Deleting packets older than \(startOfDay)")
                
                // Only delete packets not referenced by cells
                let predicate = NSPredicate(format: "collected < %@ AND index = nil AND cells.@count == 0", daysAgo as NSDate)
                
                let qmiCount = try deleteData(entity: PacketQMI.entity(), predicate: predicate, context: context)
                let ariCount = try deleteData(entity: PacketARI.entity(), predicate: predicate, context: context)
                logger.debug("Successfully deleted \(qmiCount + ariCount) old packets")
            }
        } catch {
            logger.warning("Failed to delete old packets: \(error)")
        }
    }
    
}
