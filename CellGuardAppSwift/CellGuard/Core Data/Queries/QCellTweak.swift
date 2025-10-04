//
//  CellTweak.swift
//  CellGuard
//
//  Created by Lukas Arnold on 04.05.24.
//

import CoreData
import Foundation

extension PersistenceController {

    /// Uses `NSBatchInsertRequest` (BIR) to import tweak cell properties into the Core Data store on a private queue.
    func importCollectedCells(from packetRefs: [NSManagedObjectID], sysdiagnoseId: NSManagedObjectID?, filter: Bool) throws -> [CCTCellProperties] {
        return try performAndWait(name: "importContext", author: "importCellTweak") { context in
            context.mergePolicy = NSMergePolicy.rollback

            // Fetch the packets
            let packets = packetRefs.compactMap { context.object(with: $0) as? any Packet }

            // Parse the cell properties from the parsed packets
            let cellParser = CCTParser()
            var cells: [(any Packet, CCTCellProperties)] = []
            for packet in packets {
                guard let collectedTimestamp = packet.collected,
                      let packetData = packet.data else {
                    continue
                }

                if let qmiPacket = packet as? PacketQMI,
                   let packetCells = try? cellParser.parseQmiCell(packetData, timestamp: collectedTimestamp, simSlot: UInt8(qmiPacket.simSlotID)) {
                    cells += packetCells.map { (packet, $0) }
                } else if let ariPacket = packet as? PacketARI,
                          let packetCells = try? cellParser.parseAriCell(packetData, timestamp: collectedTimestamp, simSlot: UInt8(ariPacket.simSlotID)) {
                    cells += packetCells.map { (packet, $0) }
                }
            }

            // Remove cell measurements that aren't different to their predecessor of the last second.
            if filter {
                var prevCellProperties: CCTCellProperties?
                cells = cells
                    .sorted { $0.1.timestamp ?? Date.distantPast < $1.1.timestamp ?? Date.distantPast }
                    .filter { (_, cellProperties) in
                        if let prevCellProperties = prevCellProperties,
                           let prevCellDate = prevCellProperties.timestamp,
                           let cellDate = cellProperties.timestamp,
                           cellDate.timeIntervalSince(prevCellDate) < 1,
                           prevCellProperties.isEqualExceptTime(other: cellProperties) {

                            return false
                        }

                        prevCellProperties = cellProperties
                        return true
                    }
            }

            // Import the cells without Batch import to set the packet relationship
            let sysdiagnose = Sysdiagnose.getSysdiagnoseById(context: context, id: sysdiagnoseId)
            let importedDate = Date()
            for (packet, cellProperties) in cells {
                let cell = CellTweak(context: context)
                cellProperties.applyTo(tweakCell: cell)
                cell.sysdiagnose = sysdiagnose

                // Set reference to packet
                if let qmiPacket = packet as? PacketQMI {
                    cell.packetQmi = qmiPacket
                } else if let ariPacket = packet as? PacketARI {
                    cell.packetAri = ariPacket
                }

                // Create a default verification state for each user-enabled pipeline
                // If the user enables another pipeline afterward, it automatically creates its verification states as needed
                if cellProperties.technology != ALSTechnology.OFF {
                    for pipelineId in UserDefaults.standard.userEnabledVerificationPipelineIds() {
                        let state = VerificationState(context: context)
                        state.pipeline = pipelineId
                        state.delayUntil = Date()

                        cell.addToVerifications(state)
                    }
                }

                cell.imported = importedDate
            }

            // Save the newly created verification states
            try context.save()

            logger.debug("Successfully inserted \(cells.count) tweak cells.")
            return cells.compactMap { $0.1 }
        } ?? []
    }

    func importSingleTweakCell(cellProperties: CCTCellProperties, verify: Bool) throws {
        try performAndWait(name: "importContext", author: "importSingleCellTweak") { context in
            let cell = CellTweak(context: context)
            cellProperties.applyTo(tweakCell: cell)

            // Create a default verification state for each user-enabled pipeline
            // If the user enables another pipeline afterward, it automatically creates its verification states as needed
            if verify && cellProperties.technology != ALSTechnology.OFF {
                for pipelineId in UserDefaults.standard.userEnabledVerificationPipelineIds() {
                    let state = VerificationState(context: context)
                    state.pipeline = pipelineId
                    state.delayUntil = Date()

                    cell.addToVerifications(state)
                }
            }

            cell.imported = Date()

            try context.save()
            logger.debug("Successfully inserted one tweak cells for testing purposes.")
        }
    }

    func fetchCellExists(properties: CCTCellProperties, before: Date?) -> Bool? {
        guard let technology = properties.technology,
              let country = properties.mcc,
              let network = properties.network,
              let area = properties.area,
              let cellId = properties.cellId else {
            return nil
        }

        return try? performAndWait(name: "fetchContext", author: "fetchCell") { context in
            let existFetchRequest = CellTweak.fetchRequest()
            existFetchRequest.fetchLimit = 1
            var predicates: [NSPredicate] = []
            predicates.append(NSPredicate(format: "technology = %@ and country = %@ and network = %@ and area = %@ and cell = %@",
                technology.rawValue as NSString, country as NSNumber, network as NSNumber, area as NSNumber, cellId as NSNumber))
            if let before = before {
                predicates.append(NSPredicate(format: "imported < %@", before as NSDate))
            }
            existFetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            let cell = try context.fetch(existFetchRequest).first
            return cell != nil
        }
    }

    func fetchCellAttribute<T>(cell: NSManagedObjectID, extract: (CellTweak) throws -> T?) -> T? {
        return try? performAndWait(name: "fetchContext", author: "fetchCellAttribute") { context in
            if let tweakCell = context.object(with: cell) as? CellTweak {
                return try extract(tweakCell)
            }

            return nil
        }
    }

    func fetchCellLifespan(of tweakCellID: NSManagedObjectID) throws -> (start: Date, end: Date, after: NSManagedObjectID, simSlotID: UInt8)? {
        return try? performAndWait(name: "fetchContext", author: "fetchCellLifespan") { context in
            guard let tweakCell = context.object(with: tweakCellID) as? CellTweak else {
                logger.warning("Can't convert NSManagedObjectID \(tweakCellID) to CellTweak")
                return nil
            }

            guard let startTimestamp = tweakCell.collected else {
                logger.warning("CellTweak \(tweakCell) has not collected timestamp")
                return nil
            }

            let request = NSFetchRequest<CellTweak>()
            request.entity = CellTweak.entity()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "collected > %@ and simSlotID = %@", startTimestamp as NSDate, tweakCell.simSlotID as NSNumber)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \CellTweak.collected, ascending: true)]
            request.returnsObjectsAsFaults = false

            let tweakCells = try request.execute()
            guard let tweakCell = tweakCells.first else {
                return nil
            }

            guard let endTimestamp = tweakCell.collected else {
                logger.warning("CellTweak \(tweakCell) has not collected timestamp")
                return nil
            }

            return (start: startTimestamp, end: endTimestamp, after: tweakCell.objectID, simSlotID: UInt8(tweakCell.simSlotID))
        }
    }

    func fetchCellDateRange() async -> ClosedRange<Date>? {
        return try? performAndWait(name: "fetchContext", author: "fetchCellDateRange") {_ in
            let firstReq: NSFetchRequest<CellTweak> = CellTweak.fetchRequest()
            firstReq.fetchLimit = 1
            firstReq.sortDescriptors = [NSSortDescriptor(keyPath: \CellTweak.collected, ascending: true)]
            firstReq.propertiesToFetch = ["collected"]
            firstReq.includesSubentities = false

            let lastReq: NSFetchRequest<CellTweak> = CellTweak.fetchRequest()
            lastReq.fetchLimit = 1
            lastReq.sortDescriptors = [NSSortDescriptor(keyPath: \CellTweak.collected, ascending: false)]
            lastReq.propertiesToFetch = ["collected"]
            lastReq.includesSubentities = false

            let firstCell = try firstReq.execute()
            let lastCell = try lastReq.execute()

            guard let firstCell = firstCell.first, let lastCell = lastCell.first else {
                return Date.distantPast...Date.distantFuture
            }

            return (firstCell.collected ?? Date.distantPast)...(lastCell.collected ?? Date.distantFuture)
        }
    }

}
