//
//  CPTCollector.swift
//  CellGuard
//
//  Created by Lukas Arnold on 09.06.23.
//

import Foundation
import OSLog

struct CPTCollector {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CPTCollector.self)
    )

    private let client: CPTClient

    init(client: CPTClient) {
        self.client = client
    }

    func collectAndStore() async throws -> (Int, Int, Int) {
        return try await withCheckedThrowingContinuation { completion in
            client.queryPackets { result in
                do {
                    let packets = try result.get()
                    let (qmiPackets, ariPackets, cells) = try Self.store(packets)
                    Self.logger.debug("Imported \(qmiPackets) QMI, \(ariPackets) ARI packets, and \(cells.count) Cells")
                    completion.resume(returning: (qmiPackets, ariPackets, cells.count))
                } catch {
                    // TODO: Count failures and if they exceed a given threshold, output a warning notification
                    Self.logger.warning("Can't request packets from tweak: \(error)")
                    completion.resume(throwing: error)
                }
            }
        }
    }

    public static func store(_ packets: [CPTPacket]) throws -> (Int, Int, [CCTCellProperties]) {
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

            let (_, qmiCellPackets) = try PersistenceController.shared.importQMIPackets(from: qmiPackets)
            let (_, ariCellPackets) = try PersistenceController.shared.importARIPackets(from: ariPackets)
            let importedCells = try PersistenceController.shared.importCollectedCells(from: qmiCellPackets + ariCellPackets, filter: true)

            return (qmiPackets.count, ariPackets.count, importedCells)
        } catch {
            Self.logger.warning("Can't import packets: \(error)")
            throw error
        }
    }

}
