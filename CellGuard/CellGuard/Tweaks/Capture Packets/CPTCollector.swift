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
    
    func collectAndStore(completion: @escaping (Result<(Int, Int),Error>) -> Void) {
        client.queryPackets { result in
            do {
                let packets = try result.get()
                let numberOfStoredCells = try store(packets)
                completion(.success(numberOfStoredCells))
            } catch {
                // TODO: Count failures and if they exceed a given threshold, output a warning notification
                Self.logger.warning("Can't request cells from tweak: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    private func store(_ packets: [CPTPacket]) throws -> (Int, Int) {
        do {
            var qmiPackets: [(CPTPacket, ParsedQMIPacket)] = []
            var ariPackets: [(CPTPacket, ParsedARIPacket)] = []
            
            for packet in packets {
                do {
                    let parsedPacket = try packet.parse()
                    if let qmiPacket = parsedPacket as? ParsedQMIPacket {
                        qmiPackets.append((packet, qmiPacket))
                    } else if let ariPacket = parsedPacket as? ParsedARIPacket {
                        ariPackets.append((packet, ariPacket))
                    } else {
                        Self.logger.warning("Can't parse packet: Missing implementation for packet protocol \(packet.proto.rawValue)")
                    }
                } catch {
                    print(packet.description)
                    Self.logger.warning("Can't parse packet: \(error)\n\(packet)")
                }
            }
            
            try PersistenceController.shared.importQMIPackets(from: qmiPackets)
            try PersistenceController.shared.importARIPackets(from: ariPackets)
            
            return (qmiPackets.count, ariPackets.count)
        } catch {
            Self.logger.warning("Can't import packets: \(error)")
            throw error
        }
    }
    
}
