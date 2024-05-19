//
//  StudyTask.swift
//  CellGuard
//
//  Created by Lukas Arnold on 14.05.24.
//

import CoreData
import Foundation

struct StudyTask {
    
    private let persistence = PersistenceController.shared
    private let client = StudyClient()
    
    // TODO: Create task in CellGuardAppDelegate.swift
    
    func run() async throws {
        guard let participationSince = UserDefaults.standard.date(forKey: UserDefaultsKeys.study.rawValue) else {
            return
        }
        
        // Query all cells relevant for the study which have not been uploaded
        let studyCells = try persistence.fetchStudyUploadCells(startDate: participationSince)
        if !studyCells.isEmpty {
            // Upload those cells to the backend
            let studyCellsWithoutFeedback = studyCells.map { CellIdWithFeedback(cell: $0, feedbackComment: nil, feedbackLevel: nil) }
            try await client.uploadCellSamples(cells: studyCellsWithoutFeedback)
        }
        
        // TODO: Gather and upload weekly summary
        // - Check if the study participation was activated before the last week
        // --> Do we want to use fixed intervals (from Monday UTC to Sunday UTC) or intervals based on the activation of the switch?
        // - Generate weekly report from DB
    }
    
}
