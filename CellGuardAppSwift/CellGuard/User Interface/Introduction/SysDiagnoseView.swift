//
//  SysDiagnoseView.swift
//  CellGuard
//
//  Created by jiska on 20.05.24.
//

import SwiftUI
import NavigationBackport

struct SysDiagnoseView: View {

    var body: some View {
        VStack {
            ScrollView {
                CenteredTitleIconTextView(
                    icon: "stethoscope",
                    description: "CellGuard reads baseband management packets from system diagnoses. You can record system diagnoses with packets by installing a baseband mobile configuration profile from Apple.\n\nSystem diagnoses are compatible with up-to-date iPhones in Lockdown Mode. Note that you have to install the profile before enabling Lockdown Mode.",
                    size: 120
                )
            }

            LargeButtonLink(title: "Continue", value: IntroductionState.location, backgroundColor: .blue)
                .padding()
        }
        .navigationTitle("System Diagnoses")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NBNavigationStack {
        SysDiagnoseView()
            .nbNavigationDestination(for: IntroductionState.self) { _ in
                Text("No")
            }
    }
}
