//
//  ContributedStudyDataView.swift
//  CellGuard (AppStore)
//
//  Created by Lukas Arnold on 10.06.24.
//

import SwiftUI
import NavigationBackport

struct StudyContributionsView: View {
    var body: some View {
        List {
            ListNavigationLink(value: CellListFilterSettings(
                study: .submitted,
                timeFrame: .pastDays,
                date: Date.distantPast
            )) {
                Text("Cells")
            }

            ListNavigationLink(value: SummaryNavigationPath.userStudyScoresWeekly) {
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
