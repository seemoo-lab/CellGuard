//
//  CCTFetcher.swift
//  CellGuard
//
//  Created by Lukas Arnold on 02.01.23.
//

import Foundation
import OSLog
import CoreData

struct CCTCollector {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CCTCollector.self)
    )
    
    private let parser: CCTParser = CCTParser()
    private let client: CCTClient
    
    init(client: CCTClient) {
        self.client = client
    }
    
    func collectAndStore(completion: @escaping (Error?) -> ()) {
        client.collectCells() { result in
            do {
                store(samples: try result.get())
                completion(nil)
            } catch {
                Self.logger.warning("Can't request cells from tweak: \(error)")
                completion(error)
            }
        }
    }
    
    private func store(samples: [CellSample]) {
        do {
            let importCells = try samples.map {sample -> CCTCellProperties? in
                do {
                    return try parser.parse(sample)
                } catch let error as CCTParserError {
                    Self.logger.warning("Can't parse cell sample: \(error)\n\(sample)")
                    return nil
                }
            }.compactMap { $0 }
            
            try PersistenceController.shared.importCollectedCells(from: importCells)
        } catch {
            Self.logger.warning("Can't import cells: \(error)")
        }
    }
    
}
