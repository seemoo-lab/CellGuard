//
//  ContributedStudyDataView.swift
//  CellGuard (AppStore)
//
//  Created by Lukas Arnold on 10.06.24.
//

import SwiftUI

struct StudyContributionsView: View {

    @EnvironmentObject private var filter: CellListFilterSettings
    @EnvironmentObject private var navigator: NavigationRouter

    var body: some View {
        List {
            ListNavigationButton {
                // Adjust the cell filter
                filter.reset()
                filter.study = .submitted
                filter.timeFrame = .pastDays
                filter.date = Date.distantPast

                // Open the view
                navigator.push(SummaryNavigationPath.cellList)
            } label: {
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
    CGNavigationStack {
        StudyContributionsView()
            .cgNavigationDestinations(.summaryTab)
    }
    .environmentObject(CellListFilterSettings())
}
