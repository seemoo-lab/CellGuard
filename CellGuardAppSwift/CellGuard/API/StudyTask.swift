//
//  StudyTask.swift
//  CellGuard
//
//  Created by Lukas Arnold on 14.05.24.
//

import CoreData
import Foundation
import OSLog

struct StudyTask {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: StudyTask.self)
    )
    
    private let persistence = PersistenceController.shared
    private let client = StudyClient()
    private let calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    
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
        
        // Get the beginning of the current week (UTC) and query all relevant weekly scores that should be uploaded
        let beginningOfWeek = calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: Date())
        if let beginningOfWeek = beginningOfWeek.date {
            let weeklyScores = try persistence.fetchWeeklyUploadScores(week: beginningOfWeek)
            if !weeklyScores.isEmpty {
                // Upload those weekly scores to the backend
                try await client.uploadWeeklyDetectionSummary(scoreIds: weeklyScores)
            }
        } else {
            Self.logger.info("Can't determine beginning of week: \(beginningOfWeek)")
        }
    }
    
}
