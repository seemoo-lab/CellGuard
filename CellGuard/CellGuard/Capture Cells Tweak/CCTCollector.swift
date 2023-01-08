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
    
    private let client: CCTClient
    private let parser = CCTParser(context: PersistenceController.shared.container.newBackgroundContext())
    
    init(client: CCTClient) {
        self.client = client
    }
    
    func collectAndStore(completion: @escaping (Error?) -> ()) {
        client.collectCells() { result in
            do {
                try store(samples: try result.get())
                completion(nil)
            } catch {
                Self.logger.warning("Can't request cells from tweak: \(error)")
                completion(error)
            }
        }
    }
    
    private func store(samples: [CellSample]) throws {
        let source = CellSource(context: parser.context)
        source.timestamp = Date()
        source.type = CellSourceType.tweak.rawValue
        
        _ = try samples.map {sample -> Cell? in
            do {
                return try parser.parse(sample)
            } catch let error as CCTParserError {
                Self.logger.warning("Can't parse cell sample: \(error)\n\(sample)")
                return nil
            }
        }.compactMap { $0 }.map {cell -> Cell in
            cell.source = source
            return cell
        }
        
        // TODO: Connect with locations based on last recorded location
        
        try parser.context.save()
    }
    
}
