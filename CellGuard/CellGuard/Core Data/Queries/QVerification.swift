//
//  Verification.swift
//  CellGuard (AppStore)
//
//  Created by Lukas Arnold on 30.04.24.
//

import Foundation
import CoreData

extension PersistenceController {
    
    func fetchNextVerification(pipelineId: Int16) throws -> (stage: Int16, score: Int16, statusId: NSManagedObjectID, cellId: NSManagedObjectID, cellProperties: ALSQueryCell)? {
        // TODO: Issue sometimes observed ->
        // Thread Performance Checker: Thread running at User-interactive quality-of-service class waiting on a lower QoS thread running at Background quality-of-service class. Investigate ways to avoid priority inversions.
        
        return try performAndWait { (context) -> (Int16, Int16, NSManagedObjectID, NSManagedObjectID, ALSQueryCell)? in
            let request = VerificationState.fetchRequest()
            // It's important to wrap NSPredicate arguments as NSNumber's otherwise the app crashes with EXC_BAD_ACCESS.
            // See: https://stackoverflow.com/a/28622582
            request.predicate = NSPredicate(format: "finished == NO AND pipeline == %@ AND delayUntil <= %@ AND cell != NIL", Int(pipelineId) as NSNumber, Date() as NSDate)
            // TODO: Check if that works
            request.sortDescriptors = [NSSortDescriptor(key: "cell.collected", ascending: false)]
            request.relationshipKeyPathsForPrefetching = ["cell"]
            
            guard let verificationState = (try request.execute()).first else {
                return nil
            }
            
            guard let cell = verificationState.cell else {
                // TODO: This should never be null
                return nil
            }
            
            return (verificationState.stage, verificationState.score, verificationState.objectID, cell.objectID, Self.queryCell(from: cell))
        }
    }
    
    func storeVerificationResults(statusId: NSManagedObjectID, stage: Int16, score: Int16, finished: Bool, delayUntil: Date?, logsMetadata: [VerificationStageResultLogMetadata]) throws {
        try performAndWait { context in
            guard let state = context.object(with: statusId) as? VerificationState else {
                // TODO: Throw
                return
            }
            
            // Store the updated verification state
            state.stage = stage
            state.score = score
            state.finished = finished
            state.delayUntil = delayUntil ?? Date()
            
            // Store the logs for each verification stage
            for logMetadata in logsMetadata {
                let log = VerificationLog(context: context)
                
                log.duration = logMetadata.duration
                log.pointsAwarded = logMetadata.pointsAwarded
                log.pointsMax = logMetadata.pointsMax
                log.stageId = logMetadata.stageId
                log.stageName = logMetadata.stageName
                log.stageNumber = logMetadata.stageNumber
                
                if let relatedMetadata = logMetadata.relatedObjects {
                    if let relatedCellAls = relatedMetadata.cellAls {
                        log.relatedCellALS = context.object(with: relatedCellAls) as? CellALS
                    }
                    if let relatedLocationUser = relatedMetadata.locationUser {
                        log.relatedLocationUser = context.object(with: relatedLocationUser) as? LocationUser
                    }
                    for relatedPacketAri in relatedMetadata.packetsAri {
                        if let packetAri = context.object(with: relatedPacketAri) as? PacketARI {
                            log.addToRelatedPacketARI(packetAri)
                        }
                    }
                    for relatedPacketQmi  in relatedMetadata.packetsQmi {
                        if let packetQmi = context.object(with: relatedPacketQmi) as? PacketQMI {
                            log.addToRelatedPacketQMI(packetQmi)
                        }
                    }
                }
                
                state.addToLogs(log)
            }
            
            try context.save()
        }
    }
    
    
    func clearVerificationData(tweakCellID: NSManagedObjectID) throws {
        try performAndWait { taskContext in
            guard let tweakCell = taskContext.object(with: tweakCellID) as? CellTweak else {
                logger.warning("Can't clear verification data of the tweak cell with object ID: \(tweakCellID)")
                throw PersistenceError.objectIdNotFoundError
            }
            
            // Reset all verification states associated with the cell
            let states = tweakCell.verifications?.compactMap({ $0 as? VerificationState })
            states?.forEach({ state in
                state.finished = false
                state.stage = 0
                state.score = 0
                state.delayUntil = Date()
                state.logs?.compactMap({ $0 as? NSManagedObject }).forEach { taskContext.delete($0) }
            })
            
            // Reset the properties originating from the verification
            tweakCell.appleDatabase = nil
            tweakCell.location = nil
            
            // Save the changes
            try taskContext.save()
                        
            logger.debug("Cleared verification data of \(tweakCell)")
        }
    }
    
}
