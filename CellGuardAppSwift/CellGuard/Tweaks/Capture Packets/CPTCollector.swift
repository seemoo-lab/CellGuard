//
//  CPTCollector.swift
//  CellGuard
//
//  Created by Lukas Arnold on 09.06.23.
//

import Foundation
import OSLog
import CoreData

struct CPTCollector {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CPTCollector.self)
    )

    private let client: CPTClient

    init(client: CPTClient) {
        self.client = client
    }

    func collectAndStore() async throws -> (Int, Int, Int, Int) {
        return try await withCheckedThrowingContinuation { completion in
            client.queryPackets { result in
                do {
                    let packets = try result.get()
                    let (qmiPackets, ariPackets, cells, connectivity, parsingErrors) = try Self.store(packets, sysdiagnose: nil)
                    Self.logger.debug("Imported \(qmiPackets) QMI, \(ariPackets) ARI packets, and \(cells.count) Cells with \(parsingErrors.count) errors")
                    completion.resume(returning: (qmiPackets, ariPackets, cells.count, connectivity))
                } catch {
                    // TODO: Count failures and if they exceed a given threshold, output a warning notification
                    Self.logger.warning("Can't request packets from tweak: \(error)")
                    completion.resume(throwing: error)
                }
            }
        }
    }

    // store parses and stores the passed packets and returns the number of imported objects and minor errors.
    public static func store(_ packets: [CPTPacket], sysdiagnose: NSManagedObjectID?) throws -> (Int, Int, [CCTCellProperties], Int, [Error]) {
        do {
            var qmiPackets: [(CPTPacket, ParsedQMIPacket)] = []
            var ariPackets: [(CPTPacket, ParsedARIPacket)] = []

            var mostRecentPacket: Date?

            for packet in packets {
                do {
                    let parsedPacket = try packet.parse()
                    if let qmiPacket = parsedPacket as? ParsedQMIPacket {
                        qmiPackets.append((packet, qmiPacket))
                    } else if let ariPacket = parsedPacket as? ParsedARIPacket {
                        var packet = packet
                        packet.simSlotID = ariPacket.simSlotId()
                        ariPackets.append((packet, ariPacket))
                    } else {
                        Self.logger.warning("Can't parse packet: Missing implementation for packet protocol \(packet.proto.rawValue)")
                    }
                } catch {
                    print(packet.description)
                    Self.logger.warning("Can't parse packet: \(error)\n\(packet)")
                }
                if mostRecentPacket ?? Date.distantPast < packet.timestamp {
                    mostRecentPacket = packet.timestamp
                }
            }

            #if JAILBREAK
            if let mostRecentPacket = mostRecentPacket {
                UserDefaults.standard.set(mostRecentPacket, forKey: UserDefaultsKeys.mostRecentPacket.rawValue)
            }
            #endif

            let (qmiImportCount, qmiPacketRefs) = try PersistenceController.shared.importQMIPackets(from: qmiPackets, sysdiagnoseId: sysdiagnose)
            let (ariImportCount, ariPacketRefs) = try PersistenceController.shared.importARIPackets(from: ariPackets, sysdiagnoseId: sysdiagnose)
            let cellPacketRefs = qmiPacketRefs.cellInfo + ariPacketRefs.cellInfo
            let (importedCells, parsingErrors) = try PersistenceController.shared.importCollectedCells(from: cellPacketRefs, sysdiagnoseId: sysdiagnose, filter: true)
            let connectivityPacketRefs = qmiPacketRefs.connectivityEvents + ariPacketRefs.connectivityEvents
            let importedConnectivityEvents = try PersistenceController.shared.importConnectivityEvents(from: connectivityPacketRefs, sysdiagnoseId: sysdiagnose)

            return (qmiImportCount, ariImportCount, importedCells, importedConnectivityEvents, parsingErrors)
        } catch {
            Self.logger.warning("Can't import packets: \(error)")
            throw error
        }
    }

}
