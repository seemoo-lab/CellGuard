//
//  CPTClient.swift
//  CellGuard
//
//  Created by Lukas Arnold on 06.06.23.
//

import Foundation
import OSLog

struct CPTPacket {
    let proto: String
    let direction: String
    let data: Data
    let timestamp: Date
}

struct CPTClient {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CPTClient.self)
    )
    
    /// The generic tweak client
    private let client: TweakClient
    
    init(queue: DispatchQueue) {
        client = TweakClient(port: 33067, queue: queue)
    }
    
    /// Connects to the tweak, fetches all cells, and converts them into a dictionary structure.
    func queryPackets(completion: @escaping (Result<[CPTPacket], Error>) -> ()) {
        client.query { result in
            completion(.init {
                try convert(data: try result.get())
            })
        }
    }
    
    /// Converts data that has been received from the tweak into a dictionary.
    private func convert(data: Data) throws -> [CPTPacket]  {
        if data.count == 0 {
            return []
        }
        
        guard let string = String(data: data, encoding: .utf8) else {
            Self.logger.warning("Can't convert data \(data.debugDescription) to String")
            return []
        }
        
        var packets: [CPTPacket] = []
        
        // Each line received by our tweak represents on QMI or ARI packet
        let lines = string.split(whereSeparator: \.isNewline)
        for line in lines {
            // Each packet has some additional information.
            // Our tweak separates the four fields in each line using commas.
            let lineComponents = line.split(separator: ",")
            if lineComponents.count != 4 {
                Self.logger.warning("Invalid CPTPacket '\(line)': Has not exactly four components")
                continue
            }
            
            // The protocol of the recorded packet, either QMI or ARI
            let proto = lineComponents[0]
            if proto != "QMI" && proto != "ARI" {
                Self.logger.warning("Invalid CPTPacket '\(line)': Unknown protocol")
                continue
            }
            // The direction the from which packet was intercepted, either IN (Baseband -> iOS) or OUT (iOS -> Baseband)
            let direction = lineComponents[1]
            if direction != "IN" && direction != "OUT" {
                Self.logger.warning("Invalid CPTPacket '\(line)': Unknown direction")
                continue
            }
            // The actual packet data encoded with base64
            guard let data = Data(base64Encoded: String(lineComponents[2]), options: .ignoreUnknownCharacters) else {
                Self.logger.warning("Invalid CPTPacket '\(line)': Can't read base64 data from the third component")
                continue
            }
            // The timestamp when the packet was recorded
            guard let unixTimestamp = Double(String(lineComponents[3])) else {
                Self.logger.warning("Invalid CPTPacket '\(line)': Can't convert fourth component to Double")
                continue
            }
            let timestamp = Date(timeIntervalSince1970: unixTimestamp)
            
            packets.append(CPTPacket(proto: String(proto), direction: String(direction), data: data, timestamp: timestamp))
        }
        
        return packets
    }
    
}
