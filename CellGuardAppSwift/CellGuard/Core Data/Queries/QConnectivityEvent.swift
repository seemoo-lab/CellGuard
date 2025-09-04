//
//  QConnectivityEvent.swift
//  CellGuard
//
//  Created by mp on 08.07.25.
//

import CoreData
import Foundation

extension PersistenceController {

    /// Uses `NSBatchInsertRequest` (BIR) to import tweak cell properties into the Core Data store on a private queue.
    func importConnectivityEvents(from packetRefs: [NSManagedObjectID]) throws -> Int {
        return try performAndWait(name: "importContext", author: "importConnectivityEvents") { context in
            context.mergePolicy = NSMergePolicy.rollback

            // Fetch the packets
            let packets = packetRefs.compactMap { context.object(with: $0) as? any Packet }

            // Parse the connectivity events from the parsed packets
            // Import the cells without Batch import to set the packet relationship
            var importCount = 0
            let importedDate = Date()
            let eventParser = ConnectivityEventParser()
            for packet in packets {
                guard let collectedTimestamp = packet.collected,
                      let packetData = packet.data else {
                    continue
                }

                if let qmiPacket = packet as? PacketQMI,
                   let events = try? eventParser.parseQmiPacket(packetData, timestamp: collectedTimestamp, simSlot: UInt8(qmiPacket.simSlotID)) {
                    for event in events {
                        let dbEvent = ConnectivityEvent(context: context)
                        event.applyTo(connectivityEvent: dbEvent)
                        dbEvent.packetQmi = qmiPacket
                        dbEvent.imported = importedDate
                        importCount += 1
                    }
                } else if let ariPacket = packet as? PacketARI,
                          let event = try? eventParser.parseAriPacket(packetData, timestamp: collectedTimestamp, simSlot: UInt8(ariPacket.simSlotID)) {
                    let dbEvent = ConnectivityEvent(context: context)
                    event.applyTo(connectivityEvent: dbEvent)
                    dbEvent.packetAri = ariPacket
                    dbEvent.imported = importedDate
                    importCount += 1
                }
            }

            try context.save()

            logger.debug("Successfully inserted \(importCount) connectivity events.")
            return importCount
        } ?? 0
    }

    func fetchConnectivityDateRange() async -> ClosedRange<Date>? {
        return try? performAndWait(name: "fetchContext", author: "fetchConnectivityDateRange") {_ in
            let firstReq: NSFetchRequest<ConnectivityEvent> = ConnectivityEvent.fetchRequest()
            firstReq.fetchLimit = 1
            firstReq.sortDescriptors = [NSSortDescriptor(keyPath: \ConnectivityEvent.collected, ascending: true)]
            firstReq.propertiesToFetch = ["collected"]
            firstReq.includesSubentities = false

            let lastReq: NSFetchRequest<ConnectivityEvent> = ConnectivityEvent.fetchRequest()
            lastReq.fetchLimit = 1
            lastReq.sortDescriptors = [NSSortDescriptor(keyPath: \ConnectivityEvent.collected, ascending: false)]
            lastReq.propertiesToFetch = ["collected"]
            lastReq.includesSubentities = false

            let firstEvent = try firstReq.execute()
            let lastEvent = try lastReq.execute()

            guard let firstEvent = firstEvent.first, let lastEvent = lastEvent.first else {
                return Date.distantPast...Date.distantFuture
            }

            return (firstEvent.collected ?? Date.distantPast)...(lastEvent.collected ?? Date.distantFuture)
        }
    }
}
