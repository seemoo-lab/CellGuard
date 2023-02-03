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
    private let verifier: ALSVerifier = ALSVerifier()
    
    // TODO: Shared instance which exposes its last status
    
    init(client: CCTClient) {
        self.client = client
    }
    
    func collectAndStore(completion: @escaping (Result<Int,Error>) -> Void) {
        client.collectCells() { result in
            do {
                let samples = try result.get()
                let numberOfStoredCells = try store(samples: samples)
                completion(.success(numberOfStoredCells))
            } catch {
                Self.logger.warning("Can't request cells from tweak: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    private func store(samples: [CellSample]) throws -> Int {
        do {
            let importCells = try samples.compactMap {sample -> CCTCellProperties? in
                do {
                    return try parser.parse(sample)
                } catch let error as CCTParserError {
                    Self.logger.warning("Can't parse cell sample: \(error)\n\(sample)")
                    return nil
                }
            }
            
            try PersistenceController.shared.importCollectedCells(from: importCells)
            
            return importCells.count
        } catch {
            Self.logger.warning("Can't import cells: \(error)")
            throw error
        }
    }
}
