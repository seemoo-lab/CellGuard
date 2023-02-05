//
//  CCTClient.swift
//  CellGuard
//
//  Created by Lukas Arnold on 01.01.23.
//

import Foundation
import OSLog
import Network

typealias CellInfo = [String: Any]
typealias CellSample = [CellInfo]

struct CCTClient {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CCTClient.self)
    )
    
    /// The port of the tweak
    private let port = 33066
    
    /// The queue used for processing incoming messages
    let queue: DispatchQueue
    
    /// Connects to the tweak, fetches all cells, and converts them into a dictionary structure.
    func collectCells(completion: @escaping (Result<[CellSample], Error>) -> ()) {
        // https://stackoverflow.com/a/64242102
        
        let nwPort = NWEndpoint.Port(integerLiteral: UInt16(port))
        let connection = NWConnection(host: "127.0.0.1", port: nwPort, using: NWParameters.tcp)
        
        connection.stateUpdateHandler = { state in
            Self.logger.trace("Connection State: \(String(describing: state))")
        }
        
        var completed = false
        
        connection.receiveMessage { content, context, complete, error in
            Self.logger.trace("Received Message: \(content?.debugDescription ?? "nil") - \(context.debugDescription) - \(complete) - \(error)")
            if let error = error {
                // We've got an error
                completion(.failure(error))
                connection.cancel()
            } else if let content = content {
                // We've got a full response with data
                completion(.init() {
                    try self.convert(data: content)
                })
            } else if !completed {
                // We've got an empty response
                completion(.success([]))
            }
            completed = true
        }
        
        connection.start(queue: self.queue)
    }
    
    /// Converts data that has been received from the tweak into a dictionary.
    private func convert(data: Data) throws -> [CellSample]  {
        guard let string = String(data: data, encoding: .utf8) else {
            Self.logger.warning("Can't convert data \(data.debugDescription) to string")
            return []
        }
        
        let jsonFriendlyStr = "[\(string.split(whereSeparator: \.isNewline).joined(separator: ", "))]"
        
        // We're using JSONSerilization because the JSONDecoder requires specific type information that we can't provide
        return try JSONSerialization.jsonObject(with: jsonFriendlyStr.data(using: .utf8)!) as! [CellSample]
    }
    
}
