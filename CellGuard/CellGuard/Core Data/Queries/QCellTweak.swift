//
//  CellTweak.swift
//  CellGuard
//
//  Created by Lukas Arnold on 04.05.24.
//

import CoreData
import Foundation

extension PersistenceController {
    
    /// Uses `NSBatchInsertRequest` (BIR) to import tweak cell properties into the Core Data store on a private queue.
    func importCollectedCells(from cells: [CCTCellProperties]) throws {
        try performAndWait(name: "importContext", author: "importCellTweak") { context in
            context.mergePolicy = NSMergePolicy.rollback
            
            var index = 0
            let total = cells.count
            
            let importedDate = Date()
            
            let batchInsertRequest = NSBatchInsertRequest(entity: CellTweak.entity(), managedObjectHandler: { cell in
                guard index < total else { return true }
                
                if let cell = cell as? CellTweak {
                    cells[index].applyTo(tweakCell: cell)
                    cell.imported = importedDate
                }
                
                index += 1
                return false
            })
            
            batchInsertRequest.resultType = .objectIDs
            let fetchResult = try context.execute(batchInsertRequest)
            
            guard let batchInsertResult = fetchResult as? NSBatchInsertResult,
                  let objectIDs = batchInsertResult.result as? [NSManagedObjectID] else {
                logger.debug("Failed to execute batch import request for tweak cells.")
                throw PersistenceError.batchInsertError
            }
            
            // Create empty verification entries for all new cells
            // But we have to that in order and cannot use BatchInsertRequests as they don't support relationships.
            // See: https://fatbobman.com/en/posts/batchprocessingincoredata/#batch-insert
            // See: https://www.reddit.com/r/swift/comments/y2dit0/any_clean_way_for_batch_inserting_coredata/
            for objectId in objectIDs {
                guard let cell = context.object(with: objectId) as? CellTweak else {
                    continue
                }
                
                // Create a default verification state for each pipeline
                for pipeline in activeVerificationPipelines {
                    let state = VerificationState(context: context)
                    state.pipeline = pipeline.id
                    state.delayUntil = Date()
                    
                    cell.addToVerifications(state)
                }
            }
            
            // Save the newly created verification states
            try context.save()
            
            logger.debug("Successfully inserted \(cells.count) tweak cells.")
        }
    }
    
    func fetchCellAttribute<T>(cell: NSManagedObjectID, extract: (CellTweak) throws -> T?) -> T? {
        return try? performAndWait(name: "fetchContext", author: "fetchCellAttribute") { context in
            if let tweakCell = context.object(with: cell) as? CellTweak {
                return try extract(tweakCell)
            }
            
            return nil
        }
    }
    
    func fetchCellLifespan(of tweakCellID: NSManagedObjectID) throws -> (start: Date, end: Date, after: NSManagedObjectID)? {
        return try? performAndWait(name: "fetchContext", author: "fetchCellLifespan") { context in
            guard let tweakCell = context.object(with: tweakCellID) as? CellTweak else {
                logger.warning("Can't convert NSManagedObjectID \(tweakCellID) to CellTweak")
                return nil
            }
            
            guard let startTimestamp = tweakCell.collected else {
                logger.warning("CellTweak \(tweakCell) has not collected timestamp")
                return nil
            }
            
            let request = NSFetchRequest<CellTweak>()
            request.entity = CellTweak.entity()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "collected > %@", startTimestamp as NSDate)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \CellTweak.collected, ascending: true)]
            request.returnsObjectsAsFaults = false
            
            let tweakCells = try request.execute()
            guard let tweakCell = tweakCells.first else {
                return nil
            }
            
            guard let endTimestamp = tweakCell.collected else {
                logger.warning("CellTweak \(tweakCell) has not collected timestamp")
                return nil
            }
            
            return (start: startTimestamp, end: endTimestamp, after: tweakCell.objectID)
        }
    }
    
}
