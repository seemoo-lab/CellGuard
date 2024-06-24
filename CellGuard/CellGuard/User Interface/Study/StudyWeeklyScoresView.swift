//
//  StudyWeeklyScoresView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 24.06.24.
//

import SwiftUI

struct StudyWeeklyScoresView: View {
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \StudyScore.week, ascending: false)],
        predicate: NSPredicate(format: "uploaded != nil")
    )
    private var scores: FetchedResults<StudyScore>
    
    // TODO: Group by week
    // TODO: Show message if so far no data has been transmitted
    
    var body: some View {
        return List(scores) { score in
            Text("""
            Week: \(weekString(score: score))
            Country: \(score.country ?? "n/a")
            Anomalous Cells: \(percentNumberFormatter.string(for: score.rateSuspicious) ?? "n/a")
            Suspicious Cells: \(percentNumberFormatter.string(for: score.rateUntrusted) ?? "n/a")
            """)
            
        }
        .navigationTitle("Weekly Measurements")
        .listStyle(.insetGrouped)
    }
    
    private func weekString(score: StudyScore) -> String {
        guard let week = score.week else {
            return "n/a"
        }
        
        let sevenDaysBefore = week.addingTimeInterval(-60 * 60 * 24 * 7)
        
        return mediumDateFormatter.string(from: sevenDaysBefore) + " - " + mediumDateFormatter.string(from: week)
    }
    
}
