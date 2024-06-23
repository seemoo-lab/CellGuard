//
//  QStudy.swift
//  CellGuard
//
//  Created by Lukas Arnold on 13.05.24.
//

import CoreData
import Foundation

extension PersistenceController {
    
    /// Queries the database for cells which weren't uploaded so far and match the upload criteria.
    func fetchStudyUploadCells(startDate: Date) throws -> [NSManagedObjectID] {
        return try performAndWait(name: "queryTask", author: "fetchStudyUploadCells") { context in
            
            // == Fetch all cells which would be considered for the study ==
            
            let fetchRequest = VerificationState.fetchRequest()
            // Only consider cells if
            // - all verification pipelines of them are finished
            // - the primary verification pipeline has deemed the cell as suspicious
            // - the cell hasn't been uploaded
            fetchRequest.predicate = NSPredicate(
                format: "finished == YES and score < %@ and cell != nil and cell.imported >= %@ and cell.study == nil and and (ALL cell.verifications.finished == YES)",
                primaryVerificationPipeline.pointsSuspicious as NSNumber, startDate as NSDate
            )
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "cell.collected", ascending: true)]
            fetchRequest.relationshipKeyPathsForPrefetching = ["cell"]
            
            var cellsToBeUploaded = try fetchRequest.execute()
                .compactMap { $0.cell }
                .filter { $0.collected != nil }
            if cellsToBeUploaded.isEmpty {
                return []
            }
            
            // == Remove all cells from consideration if they were collected within a 15m interval of an already uploaded cell ==
            
            let startProximityDate = cellsToBeUploaded.first?.collected?.addingTimeInterval(-60 * 15)
            let endProximityDate = cellsToBeUploaded.last?.collected?.addingTimeInterval(60 * 15)
            
            let uploadDatesRequest = StudyCell.fetchRequest()
            if let startProximityDate = startProximityDate, let endProximityDate = endProximityDate {
                uploadDatesRequest.predicate = NSPredicate(format: "uploaded != nil and uploaded >= %@ and uploaded <= %@", startProximityDate as NSDate, endProximityDate as NSDate)
            }
            let uploadedCollectedDates = try uploadDatesRequest.execute().compactMap { $0.cell?.collected }
            
            cellsToBeUploaded.removeAll { cell in
                // Check with all dates of uploaded cells within range
                for date in uploadedCollectedDates {
                    if abs(cell.collected!.timeIntervalSince(date)) < 15 * 60 {
                        
                        // Store this information, so we don't have to check the cell again
                        let studyCell = StudyCell(context: context)
                        studyCell.skippedDueTime = true
                        cell.study = studyCell
                        
                        return true
                    }
                }
                
                return false
            }

            // == Remove all cells from consideration if they were collected within a 15m interval of an another not-yet-uploaded cell ==
            
            var lastDate: Date?
            cellsToBeUploaded.removeAll { cell in
                guard let lastStoredDate = lastDate else {
                    return false
                }
                
                if lastStoredDate.timeIntervalSince(cell.collected!) < 15 * 60 {
                    // If the cell object already exists, the user might have uploaded it manually by providing feedback
                    if cell.study == nil {
                        let studyCell = StudyCell(context: context)
                        studyCell.skippedDueTime = true
                        cell.study = studyCell
                    }
                    return true
                }
                
                lastDate = cell.collected
                return false
            }
            
            // Save the context and return the remaining cells satisfying the criteria
            try context.save()
            return cellsToBeUploaded.compactMap { $0.objectID }
        } ?? []
    }
    
    /// Assigns the given upload date to all cells.
    func saveStudyUploadDate(cells: [CellIdWithFeedback], uploadDate: Date) throws {
        try performAndWait(name: "updateTask", author: "setStudyUploadDate") { context in
            // Assign the upload date and optional feedback to all cells
            for cellId in cells {
                if let cell = context.object(with: cellId.cell) as? CellTweak {
                    if cell.study == nil {
                        let studyCell = StudyCell(context: context)
                        cell.study = studyCell
                    }
                    
                    cell.study?.uploaded = uploadDate
                    cell.study?.skippedDueTime = false
                    cell.study?.feedbackComment = cellId.feedbackComment
                    cell.study?.feedbackLevel = cellId.feedbackLevel?.rawValue
                }
            }
         
            // Saves the updates
            try context.save()
        }
    }
    
}
