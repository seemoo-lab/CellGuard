//
//  CCTFetcher.swift
//  CellGuard
//
//  Created by Lukas Arnold on 02.01.23.
//

import Foundation
import OSLog

struct CCTCollector {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ALSClient.self)
    )
    
    private let client = CCTClient(queue: DispatchQueue.global(qos: .userInitiated))
    
    func collectAndStore() {
        client.collectCells() { result in
            do {
                let arrayOfData = try result.get()
                // TODO: Parse & Store
            } catch {
                Self.logger.warning("Can't request cells from tweak: \(error)")
            }
        }
    }
    
    private func store() {
        
    }
    
}
