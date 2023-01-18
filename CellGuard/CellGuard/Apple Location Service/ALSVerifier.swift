//
//  ALSVerifier.swift
//  CellGuard
//
//  Created by Lukas Arnold on 18.01.23.
//

import Foundation
import CoreData
import OSLog

enum ALSVerifierError: Error {
    case timeout(seconds: Int)
}

struct ALSVerifier {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ALSVerifier.self)
    )
    
    private let persistence = PersistenceController.shared
    private let client = ALSClient()
    
    func verify(n: Int, completion: (Error?) -> Void) {
        Self.logger.debug("Verifing at max \(n) tweak cell(s)...")
        
        var queryCells: [NSManagedObjectID : ALSQueryCell] = [:]
        var fetchError: Error? = nil
        persistence.newTaskContext().performAndWait {
            let request = NSFetchRequest<TweakCell>()
            request.entity = TweakCell.entity()
            request.fetchLimit = n
            request.predicate = NSPredicate(format: "status == %@", CellStatus.imported.rawValue)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \TweakCell.collected, ascending: true)]
            request.returnsObjectsAsFaults = false
            do {
                let tweakCells = try request.execute()
                queryCells = Dictionary(uniqueKeysWithValues: tweakCells.map { ($0.objectID, queryCell(from: $0)) })
            } catch {
                fetchError = error
            }
        }
        
        Self.logger.debug("Selected \(queryCells.count) tweak cell(s) for verification")
        
        if let fetchError = fetchError {
            Self.logger.warning("Can't fetch \(n) tweak cells with status == import: \(fetchError)")
            completion(fetchError)
            return
        }
        
        // TODO: Search for query cells in database first before requesting?
        
        // We're using a dispatch group to provide a callback when all operations are finished
        let group = DispatchGroup()
        
        queryCells.forEach { objectID, queryCell in
            group.enter()
            client.requestCells(
                origin: queryCell,
                completion: { result in
                    processQueriedCells(result: result, cellId: objectID)
                    group.leave()
                }
            )
        }
        
        let timeResult = group.wait(wallTimeout: DispatchWallTime.now() + DispatchTimeInterval.seconds(n * 3))
        if timeResult == .timedOut {
            Self.logger.warning("Fetch operation for \(n) tweak timed out after \(n * 3)s")
            completion(ALSVerifierError.timeout(seconds: n * 3))
        } else {
            Self.logger.debug("Checked the verification status of \(n) tweak cells")
            completion(nil)
        }
    }
    
    func verify(cells: [TweakCell], completion: (Error?) -> Void) {
        
    }
    
    private func processQueriedCells(result: Result<[ALSQueryCell], Error>, cellId: NSManagedObjectID) {
        switch (result) {
        case .failure(let error):
            Self.logger.warning("Can't fetch ALS cells for tweak cell: \(error)")
            
        case .success(let queryCells):
            Self.logger.debug("Received \(queryCells.count) cells from ALS")
            
            // Remove query cells with are only are rough approixmation
            let queryCells = queryCells.filter { $0.hasCellId() }
            
            // Check if the resuling ALS cell is valid
            if !(queryCells.first?.isValid() ?? false) {
                
                // If not, set the status of the origin cell to failed
                let context = persistence.newTaskContext()
                context.performAndWait {
                    // TODO: Does this work?
                    if let tweakCell = context.object(with: cellId) as? TweakCell {
                        tweakCell.status = CellStatus.failed.rawValue
                        do {
                            try context.save()
                        } catch {
                            Self.logger.warning("Can't save tweak cell (\(tweakCell) with status == failed: \(error)")
                        }
                    } else {
                        Self.logger.warning("Can't apply status == failed to tweak cell with object ID: \(cellId)")
                    }
                }
                
                return
            }
            
            // If yes, import the cells
            do {
                try persistence.importALSCells(from: queryCells, source: cellId)
            } catch {
                Self.logger.warning("Can't import ALS cells \(queryCells): \(error)")
            }
        }
    }
    
    private func queryCell(from cell: TweakCell) -> ALSQueryCell {
        let technology = ALSTechnology(rawValue: cell.technology ?? "LTE") ?? .LTE
        
        return ALSQueryCell(
            technology: technology,
            country: cell.country,
            network: cell.network,
            area: cell.area,
            cell: cell.cell
        )
    }
    
}
