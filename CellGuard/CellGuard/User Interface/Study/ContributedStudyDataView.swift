//
//  ContributedStudyDataView.swift
//  CellGuard (AppStore)
//
//  Created by Lukas Arnold on 10.06.24.
//

import SwiftUI

struct ContributedStudyDataView: View {
    var body: some View {
        // TODO: Implement
        // TODO: Show message if so far no data has been transmitted
        List {
            Text("Cells")
            Text("Weekly Measurements")
        }
        .navigationTitle("Your Contributions")
        .listStyle(.insetGrouped)
    }
}

#Preview {
    ContributedStudyDataView()
}
