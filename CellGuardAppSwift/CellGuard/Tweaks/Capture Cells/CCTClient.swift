//
//  CCTClient.swift
//  CellGuard
//
//  Created by Lukas Arnold on 01.01.23.
//

import Foundation
import OSLog

typealias CellInfo = [String: Any]
typealias CellSample = [CellInfo]

struct CCTClient {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CCTClient.self)
    )
    
    /// The last timestamp of when a connection was ready to receive data
    static var lastConnectionReady: Date {
        get {
            connectionReadyLock.lock()
            defer { connectionReadyLock.unlock() }
            return _lastConnectionReady
        }
        set {
            connectionReadyLock.lock()
            defer { connectionReadyLock.unlock() }
            _lastConnectionReady = newValue
        }
    }
    private static var _lastConnectionReady: Date = Date.distantPast
    private static var connectionReadyLock = NSLock()

    
    /// The generic tweak client
    private let client: TweakClient
    
    init(queue: DispatchQueue) {
        client = TweakClient(port: 33066, queue: queue)
    }
    
    /// Connects to the tweak, fetches all cells, and converts them into a dictionary structure.
    func queryCells(completion: @escaping (Result<[CellSample], Error>) -> ()) {
        client.query { result in
            completion(.init {
                try convert(data: try result.get())
            })
        } ready: {
            Self.lastConnectionReady = Date()
        }
    }
    
    /// Converts data that has been received from the tweak into a dictionary.
    private func convert(data: Data) throws -> [CellSample]  {
        if data.count == 0 {
            return []
        }
        
        guard let string = String(data: data, encoding: .utf8) else {
            Self.logger.warning("Can't convert data \(data.debugDescription) to String")
            return []
        }
        
        let jsonFriendlyStr = "[\(string.split(whereSeparator: \.isNewline).joined(separator: ", "))]"
        
        // We're using JSONSerialization because the JSONDecoder requires specific type information that we can't provide
        return try JSONSerialization.jsonObject(with: jsonFriendlyStr.data(using: .utf8)!) as! [CellSample]
    }
    
}
