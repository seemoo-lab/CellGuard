//
//  CPTClient.swift
//  CellGuard
//
//  Created by Lukas Arnold on 06.06.23.
//

import Foundation
import OSLog

enum CPTProtocol: String {
    case qmi = "QMI"
    case ari = "ARI"
}

enum CPTDirection: String {
    case ingoing = "IN"
    case outgoing = "OUT"
}

enum CPTPacketErrors: Error {
    case noProtoFound
}

struct CPTPacket: CustomStringConvertible {
    let proto: CPTProtocol
    let direction: CPTDirection
    let data: Data
    let timestamp: Date
    var simSlotID: UInt8?

    init(direction: CPTDirection, data: Data, timestamp: Date, simSlotID: UInt8? = nil, knownProtocol: CPTProtocol? = nil) throws {
        self.direction = direction
        self.data = data
        self.timestamp = timestamp
        self.simSlotID = simSlotID

        if let p = knownProtocol {
            self.proto = p
        } else {
            // TODO: ARI typically starts with "de c0 7e ab", but can also start with
            // "7e ab 68 68", "7e ab 08 6a", etc. but then length field is wrong
            if data.count >= 4 && data.subdata(in: 0..<4) == Data([0xDE, 0xC0, 0x7E, 0xAB]) {
                self.proto = .ari
            } else if data.count >= 1 && data.subdata(in: 0..<1) == Data([0x01]) {
                self.proto = .qmi
            } else {
                throw CPTPacketErrors.noProtoFound
            }
        }
    }

    var description: String {
        return "\(proto),\(direction),\(data.base64EncodedString()),\(timestamp)"
    }

    func parse() throws -> ParsedPacket {
        switch proto {
        case .qmi:
            return try ParsedQMIPacket(nsData: data)
        case .ari:
            return try ParsedARIPacket(data: data)
        }
    }
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
    func queryPackets(completion: @escaping (Result<[CPTPacket], Error>) -> Void) {
        client.query { result in
            completion(.init {
                try convert(data: try result.get())
            })
        } ready: { (hello) in
            // Can be called multiple times:
            // - Once a connection is established (hello == nil)
            // - Once a hello message from the tweak is received (hello != nil)

            // Publish changes via the main thread
            Task {
                await MainActor.run {
                    CPTClientState.shared.update(hello)
                }
            }
        }
    }

    /// Converts data that has been received from the tweak into a dictionary.
    private func convert(data: Data) throws -> [CPTPacket] {
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
            // Our tweak separates the five fields in each line using commas.
            let lineComponents = line.split(separator: ",").map { String($0) }
            if lineComponents.count != 4 {
                Self.logger.warning("Invalid CPTPacket '\(line)': Has not exactly five components")
                continue
            }

            // The direction the from which packet was intercepted, either IN (Baseband -> iOS) or OUT (iOS -> Baseband)
            guard let direction = CPTDirection(rawValue: lineComponents[0]) else {
                Self.logger.warning("Invalid CPTPacket '\(line)': Unknown direction")
                continue
            }
            // The simSlot specifies the slot of the SIM associated with the QMI packet.
            guard let simSlot = UInt8(lineComponents[1]) else {
                Self.logger.warning("Invalid CPTPacket '\(line)': Can't convert third component to UInt8")
                continue
            }
            // The actual packet data encoded with base64
            guard let data = Data(base64Encoded: lineComponents[2], options: .ignoreUnknownCharacters) else {
                Self.logger.warning("Invalid CPTPacket '\(line)': Can't read base64 data from the fourth component")
                continue
            }
            // The timestamp when the packet was recorded
            guard let unixTimestamp = Double(lineComponents[3]) else {
                Self.logger.warning("Invalid CPTPacket '\(line)': Can't convert fifth component to Double")
                continue
            }
            let timestamp = Date(timeIntervalSince1970: unixTimestamp)

            do {
                packets.append(try CPTPacket(direction: direction, data: data, timestamp: timestamp, simSlotID: simSlot))
            } catch {
                Self.logger.warning("Invalid CPTPacket '\(line)': \(error)")
            }
        }

        return packets
    }

}

class CPTClientState: ObservableObject {

    static let shared = CPTClientState()

    @Published var lastHello: TweakHelloMessage?
    @Published var lastConnection: Date?

    func update(_ hello: TweakHelloMessage?) {
        if let hello = hello {
            self.lastHello = hello
        }
        self.lastConnection = Date()
    }

}
