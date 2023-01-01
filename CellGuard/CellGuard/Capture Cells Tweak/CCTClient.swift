//
//  CCTClient.swift
//  CellGuard
//
//  Created by Lukas Arnold on 01.01.23.
//

import Foundation
import OSLog
import Network

struct CCTClient {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ALSClient.self)
    )
    
    private let port = 33066
    let queue: DispatchQueue
    
    func collectCells(completion: @escaping (Result<[[[String: Any]]], Error>) -> ()) {
        // https://stackoverflow.com/a/64242102
        
        let nwPort = NWEndpoint.Port(integerLiteral: UInt16(port))
        let connection = NWConnection(host: "127.0.0.1", port: nwPort, using: NWParameters.tcp)
        
        connection.stateUpdateHandler = { state in
            Self.logger.trace("Connection State: \(self.connectionStateString(state))")
        }
        
        var completed = false
        
        connection.receiveMessage { content, context, complete, error in
            Self.logger.trace("Received Message: \(content?.debugDescription ?? "nil") - \(context.debugDescription) - \(complete) - \(error)")
            if let error = error {
                // We've got an error
                completion(.failure(error))
                completed = true
                return
            } else if let content = content {
                // We've got a full response with data
                completion(.init() {
                    // TODO: Test it
                    try self.convert(data: content)
                })
                completed = true
            } else if !completed {
                // We've got an empty response
                completion(.success([]))
                completed = true
            }
        }
        
        connection.start(queue: self.queue)
    }
    
    private func convert(data: Data) throws -> [[[String: Any]]]  {
        guard let string = String(data: data, encoding: .utf8) else {
            Self.logger.warning("Can't convert data \(data.debugDescription) to string")
            return []
        }
        
        let jsonFriendlyStr = "[\(string.split(whereSeparator: \.isNewline).joined(separator: ", "))]"
        
        // We're using JSONSerilization because the JSONDecoder requires specific type information that we can't provide
        return try JSONSerialization.jsonObject(with: jsonFriendlyStr.data(using: .utf8)!) as! [[[String : Any]]]
    }

    private func connectionStateString(_ state: NWConnection.State) -> String {
        switch state {
        case .ready: return "Ready"
        case .preparing: return "Preparing"
        case .setup: return "Setup"
        case .waiting(let error): return "Waiting: \(error)"
        case .cancelled: return "Cancelled"
        case .failed(let error): return "Failed: \(error)"
        default: return "Unknown"
        }
    }
    
}
