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

                let dbEvent = ConnectivityEvent(context: context)
                if let qmiPacket = packet as? PacketQMI,
                   let event = try? eventParser.parseQmiPacket(packetData, timestamp: collectedTimestamp, simSlot: UInt8(qmiPacket.simSlotID)) {
                    event.applyTo(connectivityEvent: dbEvent)
                    dbEvent.packetQmi = qmiPacket
                }
                // ToDo: ARI

                dbEvent.imported = importedDate
                importCount += 1
            }

            try context.save()

            logger.debug("Successfully inserted \(importCount) connectivity events.")
            return importCount
        } ?? 0
    }
}
