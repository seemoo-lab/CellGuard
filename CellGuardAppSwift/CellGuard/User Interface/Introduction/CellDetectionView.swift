//
//  CellDetectionView.swift
//  CellGuard
//
//  Created by jiska on 20.05.24.
//

import SwiftUI
import NavigationBackport

struct CellDetectionView: View {

    var body: some View {
        VStack {
            ScrollView {
                // TODO: Mark the words "legitimate network setup" with a bold font
                CenteredTitleIconTextView(
                    icon: icon,
                    description: """
CellGuard detects suspicious network cell behavior based on management information exchanged when connecting to base stations.

Note that CellGuard senses anomalies that, in most cases, originate from legitimate network setups. For example, if your cellular network provider's coverage is low, your iPhone might connect to third-party networks. CellGuard also detects new cells added to a network, usually resulting from a change by an authorized service provider.

In a few cases, these anomalies indicate an attack by a fake base station. Such an attack could lead to tracking of your iPhone's location, network traffic interception and manipulation, and enable attackers to launch remote code execution attacks on the baseband chip.
""",
                    size: 120
                )
            }

            LargeButtonLink(title: "Continue", value: IntroductionState.userStudy, backgroundColor: .blue)
                .padding()
        }
        .navigationTitle("Fake Base Stations")
        .navigationBarTitleDisplayMode(.large)
    }

    private var icon: String {
        if #available(iOS 16, *) {
            return "cellularbars"
        } else {
            return "antenna.radiowaves.left.and.right"
        }
    }
}

#Preview {
    NBNavigationStack {
        CellDetectionView()
            .nbNavigationDestination(for: IntroductionState.self) { _ in
                Text("No")
            }
    }
}
