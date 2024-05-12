//
//  VerificationPipeline.swift
//  CellGuard
//
//  Created by Lukas Arnold on 29.04.24.
//

import Foundation
import CoreData
import OSLog

let primaryVerificationPipeline = CGVerificationPipeline.instance
let activeVerificationPipelines: [VerificationPipeline] = [
    CGVerificationPipeline.instance,
    SNVerificationPipeline.instance
]

struct VerificationStageRelatedObjects {
    /// ID of related cell from ALS
    var cellAls: NSManagedObjectID?
    
    /// ID of related user location
    var locationUser: NSManagedObjectID?
    
    /// IDs of related ARI packets
    var packetsAri: [NSManagedObjectID] = []
    
    /// IDs of related QMI packets
    var packetsQmi: [NSManagedObjectID] = []
}

enum VerificationStageResult: CustomStringConvertible {
    /// Delay the execution of the stage this cell by the number of seconds
    case delay(seconds: Int)
    
    /// Award 0 points
    case fail(related: VerificationStageRelatedObjects? = nil)
    /// Award a partial number of points
    case partial(points: Int16, related: VerificationStageRelatedObjects? = nil)
    /// Award full points
    case success(related: VerificationStageRelatedObjects? = nil)
    
    /// Abort the pipeline and award full points across it
    case finishEarly
    
    var description: String {
        switch self {
        case let .delay(seconds):
            return "delay(seconds: \(seconds))"
        case let .fail(related):
            return "fail(related: \(related.debugDescription))"
        case let .partial(points, related):
            return "partial(points: \(points), related: \(related.debugDescription))"
        case let .success(related):
            return "success(related: \(related.debugDescription))"
        case .finishEarly:
            return "finishEarly"
        }
    }
}

struct VerificationStageResultLogMetadata {
    /// The unique identifier of the verification stage
    var stageId: Int16
    
    /// The number of the stage in the pipeline
    var stageNumber: Int16
    
    /// The number of points awarded by the execution of the stage
    var pointsAwarded: Int16
    
    /// The maximum number of points the stage can award
    var pointsMax: Int16
    
    /// The start date of the execution of the pipeline
    var timestampStart: Date
    
    /// The duration the execution took
    var duration: TimeInterval
    
    /// Related objects found by the verification stage
    var relatedObjects: VerificationStageRelatedObjects?
}

protocol VerificationStage {
    
    /// A unique identifier for the stage within all the pipeline it is used
    var id: Int16 { get }
    
    /// The name of this verification stage, ensure it is registered with the backend
    var name: String { get }
    
    /// A textual description of the stage's purpose, shown in the app
    var description: String { get }
    
    /// The maximum number of points this verification stage can award
    var points: Int16 { get }
    
    /// If the stage waits to receive all packets collected during a cell's lifetime
    var waitForPackets: Bool { get }
    
    /// This function determines the points to award by the stage for the given cell
    func verify(
        queryCell: ALSQueryCell,
        queryCellId: NSManagedObjectID,
        logger: Logger
    ) async throws -> VerificationStageResult
    
}

protocol VerificationPipeline {
    
    /// The name of this verification pipeline, ensure it is registered with the backend
    var name: String { get }
    
    /// The numerical id of the verification pipeline
    var id: Int16 { get }
    
    /// The stages of this verification pipeline in order
    var stages: [VerificationStage] { get }
    
    /// The logger used by the verification pipeline
    var logger: Logger { get }
    
}

extension VerificationPipeline {
    
    // TODO: Compute these properties only once
    
    /// The maximum number of points this verification pipeline can award
    var pointsMax: Int16 {
        stages.map { $0.points }.reduce(0, +)
    }
    
    /// The exclusive upper bound for a cell to be classified as suspicious
    var pointsSuspicious: Int16 {
        Int16((Double(pointsMax) * 0.95).rounded(.down))
    }
    
    /// The exclusive upper bound for a cell to be classified as untrusted
    var pointsUntrusted: Int16 {
        Int16((Double(pointsMax) * 0.5).rounded(.down))
    }
    
}

extension VerificationPipeline {
    
    /// The first index of a stage waiting for all packets of a cell to be received.
    var stageNumberWaitingForPackets: Int {
        return stages.firstIndex { $0.waitForPackets } ?? stages.count
    }
    
}

enum VerificationPipelineError: Error {
    case fetchCellToVerify(Error)
    case invalidCellStatus
    case verifiedCellFetched
    case fetchCellsFromALS(Error)
    case importALSCells(Error)
    case fetchPackets(Error)
    
    case stageFailed(String, Error)
}

extension VerificationPipeline {
    
    func run() async {
        logger.debug("Starting verification pipeline")
        
        checkStages()
        
        while (true) {
            // Don't verify cells while an import process is active
            if PortStatus.importActive.load(ordering: .relaxed) {
                // Sleep for one second
                try? await Task.sleep(nanoseconds: NSEC_PER_SEC)
            }
            
            // Timeout for async task: https://stackoverflow.com/a/75039407
            let verifyTask = Task {
                let taskResult = try await pickCellAndVerify()
                // Without checkCancellation, verifyFirst() would keep going until infinity
                try Task.checkCancellation()
                return taskResult
            }
            
            // Set a timeout of 10s for each individual cell verification
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: 10 * NSEC_PER_SEC)
                verifyTask.cancel()
                logger.warning("Cell verification timed out after 10s")
            }
            
            do {
                // Wait for the value
                let result = try await verifyTask.value
                // Cancel the timeout task if we've got the value before the timeout
                timeoutTask.cancel()
                // If there was no cell to verify, we sleep for 500ms
                if !result {
                    try? await Task.sleep(nanoseconds: 500 * NSEC_PER_MSEC)
                }
            } catch {
                logger.warning("Cell verification resulted in an error: \(error)")
            }
        }
    }
    
    private func checkStages() {
        // Checking for multiple stages in the pipeline with the same stageId (which is not allowed)
        let stagesDict = Dictionary(grouping: stages, by: { $0.id })
        for (stageId, stages) in stagesDict {
            if stages.count > 1 {
                let stageNames = stages.map {$0.name}
                logger.warning("Multiple stages \(stageNames.joined(separator: ", ")) with same stageId = \(stageId)")
            }
        }
    }
    
    func pickCellAndVerify() async throws -> Bool {
        let persistence = PersistenceController.shared
        
        // Fetch the cell collected last for verification
        let nextCell: (stage: Int16, score: Int16, statusId: NSManagedObjectID, cellId: NSManagedObjectID, cellProperties: ALSQueryCell)?
        do {
            nextCell = try persistence.fetchNextVerification(pipelineId: id)
        } catch {
            throw VerificationPipelineError.fetchCellToVerify(error)
        }
                
        // Check if there is a cell to verify
        guard let (startStageNumber, startScore, statusId, queryCellId, queryCell) = nextCell else {
            // There is currently no cell to verify
            return false
        }

        var stageNumber = startStageNumber
        var score = startScore
        var finished = false
        var delay: Date?
        var logMetadata: [VerificationStageResultLogMetadata] = []
        
        logger.debug("Resuming verification of cell \(queryCell) with stageId = \(stageNumber) and score = \(score)")
        
        // Continue with the correct verification stage (at max 10 verification stages each time)
        outer: for i in 0...10 {
            let thisStageNumber = stageNumber
            
            // Verification is finished when if we iterated through all stages
            if stageNumber >= stages.count {
                logger.debug("Finished verification of \(queryCell) with score = \(score)")
                finished = true
                break outer
            }
            
            // Get the verification stage based on its id
            let stage = stages[Int(stageNumber)]
            
            // Run the verification stage for the cell's current state & measure its time
            let stageStartTimestamp = Date()
            let result: VerificationStageResult
            do {
                result = try await stage.verify(queryCell: queryCell, queryCellId: queryCellId, logger: logger)
            } catch {
                // TODO: Increase delay to continue verifying other cells
                throw VerificationPipelineError.stageFailed(stage.name, error)
            }
            let stageDuration = abs(stageStartTimestamp.timeIntervalSinceNow)
            
            logger.debug("Verification Iteration i = \(i) with stage = \(stage.name) took \(stageDuration)s -> \(result)")
            
            // Temporary variables evaluated based on the result
            let stagePoints: Int16
            var relatedObjects: VerificationStageRelatedObjects?
            
            // Based on the stage's result, we choose our course of action
            switch (result) {
            case let .delay(seconds):
                delay = Date().addingTimeInterval(TimeInterval(seconds))
                break outer
                
            case let .fail(related):
                stageNumber += 1
                stagePoints = 0
                relatedObjects = related
                
            case let .partial(points, related):
                stageNumber += 1
                stagePoints = points
                relatedObjects = related
                if points > stage.points {
                    logger.warning("Partial points \(points) of stage \(stage.name) are larger than its maximum points \(stage.points)")
                }
            
            case let .success(related):
                stageNumber += 1
                stagePoints = stage.points
                relatedObjects = related
                
            case .finishEarly:
                stageNumber = Int16(stages.count)
                score = 0
                stagePoints = pointsMax
            }
            
            if stagePoints < 0 {
                logger.warning("The stage points \(stagePoints) awarded by stage \(stage.name) are negative")
            }
            
            logger.debug("Updating score \(score) + \(stagePoints) = \(score + stagePoints)")
            score += stagePoints
            
            logMetadata.append(VerificationStageResultLogMetadata(
                stageId: stage.id,
                stageNumber: thisStageNumber,
                pointsAwarded: stagePoints,
                pointsMax: stage.points,
                timestampStart: stageStartTimestamp,
                duration: stageDuration,
                relatedObjects: relatedObjects
            ))
        }
        
        // Persist results of the verification for this cell
        try persistence.storeVerificationResults(statusId: statusId, stage: stageNumber, score: score, finished: finished, delayUntil: delay, logsMetadata: logMetadata)
        
        // We've verified a cell, so return true
        return true
    }
    
}
