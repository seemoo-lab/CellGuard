//
//  ContributedStudyDataView.swift
//  CellGuard (AppStore)
//
//  Created by Lukas Arnold on 10.06.24.
//

import SwiftUI

struct StudyContributionsView: View {
    var body: some View {
        List {
            NavigationLink {
                CellListView(settings: CellListFilterSettings(
                    study: .submitted,
                    timeFrame: .pastDays,
                    date: Date.distantPast
                ))
            } label: {
                Text("Cells")
            }
            
            NavigationLink {
                StudyWeeklyScoresView()
            } label: {
                Text("Weekly Measurements")
            }
        }
        .navigationTitle("Your Contributions")
        .listStyle(.insetGrouped)
    }
}

#Preview {
    StudyContributionsView()
}
