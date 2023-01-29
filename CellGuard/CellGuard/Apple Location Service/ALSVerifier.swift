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
    
    func verify(n: Int) {
        self.verify(n: n) { _ in }
    }
    
    func verify(n: Int, completion: (Error?) -> Void) {
        Self.logger.debug("Verifing at max \(n) tweak cell(s)...")
        
        // Fetch n of the latest unverified cells
        let queryCells: [NSManagedObjectID : ALSQueryCell]
        do {
            queryCells = try persistence.fetchLatestUnverfiedTweakCells(count: n)
        } catch {
            completion(error)
            return
        }
        
        Self.logger.debug("Selected \(queryCells.count) tweak cell(s) for verification")
        
        // We're using a dispatch group to provide a callback when all operations are finished
        let group = DispatchGroup()
        queryCells.forEach { objectID, queryCell in
            // Signal the wait group to incrase its size by one
            group.enter()
            
            // Try to find the coresponding ALS cell in our database
            if let existing = try? persistence.assignExistingALSIfPossible(to: objectID), existing {
                Self.logger.info("Verified tweak cell using the local ALS database: \(queryCell)")
                group.leave()
                return
            }
            
            // If we can't find the cell in our database, we'll query ALS
            Self.logger.info("Requesting tweak cell from the remote ALS database: \(queryCell)")
            client.requestCells(
                origin: queryCell,
                completion: { result in
                    processQueriedCells(result: result, source: objectID)
                    group.leave()
                }
            )
        }
        
        // Wait for all tasks to finish with a timeout of n * 3 seconds
        let timeResult = group.wait(wallTimeout: DispatchWallTime.now() + DispatchTimeInterval.seconds(queryCells.count * 3))
        
        // Notify the completion handler
        if timeResult == .timedOut {
            Self.logger.warning("Fetch operation for \(queryCells.count) tweak cells timed out after \(queryCells.count * 3)s")
            completion(ALSVerifierError.timeout(seconds: n * 3))
        } else {
            Self.logger.debug("Checked the verification status of \(queryCells.count) tweak cells")
            completion(nil)
        }
    }

    private func processQueriedCells(result: Result<[ALSQueryCell], Error>, source: NSManagedObjectID) {
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
                // TODO: Send a notification
                try? persistence.storeCellStatus(cellId: source, status: .failed)
                
                return
            }
            
            // TODO: Check distance between user location (+ accuary) and cell location (+ reach)
            // If this check fails, also send a notification and mark cell as failed
            
            // If yes, import the cells
            do {
                try persistence.importALSCells(from: queryCells, source: source)
            } catch {
                Self.logger.warning("Can't import ALS cells \(queryCells): \(error)")
            }
        }
    }
        
}
