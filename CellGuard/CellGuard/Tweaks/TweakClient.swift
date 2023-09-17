//
//  TweakClient.swift
//  CellGuard
//
//  Created by Lukas Arnold on 06.06.23.
//

import Foundation
import Network
import OSLog

struct TweakClient {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CCTClient.self)
    )
    
    /// The port of the tweak
    let port: Int
    
    /// The queue used for processing incoming messages
    let queue: DispatchQueue
    
    init(port: Int, queue: DispatchQueue) {
        self.port = port
        self.queue = queue
    }
    
    /// Connects to the tweak, fetches all cells, and converts them into a dictionary structure.
    func query(completion: @escaping (Result<Data, Error>) -> ()) {
        // Create a connection to localhost on the given port
        let nwPort = NWEndpoint.Port(integerLiteral: UInt16(port))
        let connection = NWConnection(host: "127.0.0.1", port: nwPort, using: NWParameters.tcp)
        
        // Print the connection state
        connection.stateUpdateHandler = { state in
            Self.logger.trace("Connection State (\(self.port)) : \(String(describing: state))")
            
            // If the connection has been refused (because the tweak is not active), we'll close it.
            // Otherwise CellGuard accumulates multiple waiting connections.
            if state == .waiting(.posix(.ECONNREFUSED)) {
                connection.cancel()
            }
        }
        
        // Create a handler for the received message
        var completed = false
        
        connection.receiveMessage { content, context, complete, error in
            Self.logger.trace("Received Message (\(self.port)): \(content?.debugDescription ?? "nil") - \(context.debugDescription) - \(complete) - \(error)")
            if let error = error {
                // We've got an error
                completion(.failure(error))
                connection.cancel()
            } else if let content = content {
                // We've got a full response with data
                completion(.success(content))
            } else if !completed {
                // We've got an empty response
                completion(.success(Data()))
            }
            completed = true
        }

        // Open the connection
        connection.start(queue: self.queue)
    }

}
