//
//  SysDiagnoseView.swift
//  CellGuard
//
//  Created by jiska on 20.05.24.
//

import SwiftUI

struct SysDiagnoseView: View {

    @State private var action: Int? = 0

    var body: some View {
        VStack {
            ScrollView {
                CenteredTitleIconTextView(
                    icon: "stethoscope",
                    description: "CellGuard reads baseband management packets from system diagnoses. You can record system diagnoses with packets by installing a baseband mobile configuration profile from Apple.\n\nSystem diagnoses are compatible with up-to-date iPhones in Lockdown Mode. Note that you have to install the profile before enabling Lockdown Mode.",
                    size: 120
                )
            }

            // Navigate to next permission, forward closing statement
            NavigationLink(destination: LocationPermissionView(), tag: 1, selection: $action) {}

            LargeButton(title: "Continue", backgroundColor: .blue) {
                self.action = 1
            }
            .padding()
        }
        .navigationTitle("System Diagnoses")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationView {
        SysDiagnoseView()
    }
}
