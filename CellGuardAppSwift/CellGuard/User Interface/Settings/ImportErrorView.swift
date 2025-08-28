//
//  ImportErrorView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 28.08.25.
//

import SwiftUI

struct FailureInfo: Hashable {
    let reason: String
}

struct ImportErrorView: View {
    let error: Error

    init(_ error: Error) {
        self.error = error
    }

    var body: some View {
        if let error = error as? LocalizedError {
            if let recoverySuggestion = error.recoverySuggestion {
                Text(error.localizedDescription + " " + recoverySuggestion)
            } else {
                Text(error.localizedDescription)
            }

            if let failureReason = error.failureReason {
                ListNavigationLink(value: FailureInfo(reason: failureReason)) {
                    Text("Failure Reason")
                }
            }

            // TODO: Enable issues & create template & link to template
            Link(destination: URL(string: "http://github.com/seemoo-lab/CellGuard")!) {
                KeyValueListRow(key: "Report on GitHub") {
                    Image(systemName: "link")
                }
            }
        } else {
            Text(error.localizedDescription)
        }
    }
}

struct ImportErrorDetailsView: View {
    let failure: FailureInfo

    var body: some View {
        ScrollView {
            Text(failure.reason)
                .font(.body)
                .padding()
        }
        .navigationTitle("Failure Reason")
    }
}
