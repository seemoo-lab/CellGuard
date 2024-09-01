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
    
    var body: some View {
        if !scores.isEmpty {
            let weeklyScores = Dictionary(grouping: scores, by: { $0.week })
                .sorted(by: { $0.key ?? Date.distantPast < $1.key ?? Date.distantPast})
            
            List(weeklyScores, id: \.key) { (week, scores) in
                StudyWeeklyView(week: week, scores: scores)
            }
            .navigationTitle("Weekly Measurements")
            .listStyle(.insetGrouped)
        } else {
            Text("No weekly scores have been transmitted so far")
                .navigationTitle("Weekly Measurements")
                .listStyle(.insetGrouped)
        }
    }
    
}

private struct StudyWeeklyView: View {
    
    let week: Date?
    let scores: [FetchedResults<StudyScore>.Element]
    
    var body: some View {
        Section(header: Text(weekString(week))) {
            ForEach(scores) { score in
                Text("""
                Country: \(score.country ?? "n/a")
                Anomalous Cells: \(percentNumberFormatter.string(for: score.rateSuspicious) ?? "n/a")
                Suspicious Cells: \(percentNumberFormatter.string(for: score.rateUntrusted) ?? "n/a")
                """)
            }
        }
    }
    
    
    private func weekString(_ week: Date?) -> String {
        guard let week = week else {
            return "n/a"
        }
        
        let sevenDaysBefore = week.addingTimeInterval(-60 * 60 * 24 * 7)
        return mediumDateFormatter.string(from: sevenDaysBefore) + " - " + mediumDateFormatter.string(from: week)
    }
    
}
