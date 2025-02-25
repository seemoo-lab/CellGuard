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
    
    static var mostRecentPacket: Date = Date(timeIntervalSince1970: 0)
    
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
                    Self.logger.debug("Imported \(qmiPackets) QMI, \(ariPackets) ARI packets, and \(cells) Cells")
                    completion.resume(returning: (qmiPackets, ariPackets, cells))
                } catch {
                    // TODO: Count failures and if they exceed a given threshold, output a warning notification
                    Self.logger.warning("Can't request packets from tweak: \(error)")
                    completion.resume(throwing: error)
                }
            }
        }
    }
    
    public static func store(_ packets: [CPTPacket]) throws -> (Int, Int, Int) {
        do {
            var qmiPackets: [(CPTPacket, ParsedQMIPacket)] = []
            var ariPackets: [(CPTPacket, ParsedARIPacket)] = []
            var cells: [CCTCellProperties] = []
            
            for packet in packets {
                do {
                    let parsedPacket = try packet.parse()
                    var packetCells: [CCTCellProperties]?
                    if let qmiPacket = parsedPacket as? ParsedQMIPacket {
                        qmiPackets.append((packet, qmiPacket))
                        packetCells = try? CCTParser().parseQMICell(packet.data, timestamp: packet.timestamp)
                    } else if let ariPacket = parsedPacket as? ParsedARIPacket {
                        ariPackets.append((packet, ariPacket))
                        packetCells = try? CCTParser().parseARICell(packet.data, timestamp: packet.timestamp)
                    } else {
                        Self.logger.warning("Can't parse packet: Missing implementation for packet protocol \(packet.proto.rawValue)")
                    }
                    
                    if let packetCells = packetCells {
                        for cell in packetCells {
                            // cells.append(cell)
                        }
                    }
                } catch {
                    print(packet.description)
                    Self.logger.warning("Can't parse packet: \(error)\n\(packet)")
                }
                if CPTCollector.mostRecentPacket < packet.timestamp {
                    CPTCollector.mostRecentPacket = packet.timestamp
                }
            }
            
            try PersistenceController.shared.importQMIPackets(from: qmiPackets)
            try PersistenceController.shared.importARIPackets(from: ariPackets)
            try PersistenceController.shared.importCollectedCells(from: cells)
            
            return (qmiPackets.count, ariPackets.count, cells.count)
        } catch {
            Self.logger.warning("Can't import packets: \(error)")
            throw error
        }
    }
    
}
