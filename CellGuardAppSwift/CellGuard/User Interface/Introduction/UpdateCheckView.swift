//
//  UpdateCheckView.swift
//  CellGuard
//
//  Created by mp on 25.04.25.
//

import SwiftUI

struct UpdateCheckView: View {

    @AppStorage(UserDefaultsKeys.updateCheck.rawValue) private var updateCheck: Bool = false
    @State private var agePolicyConfirmation: Bool = false
    @State private var action: Int? = 0

    var body: some View {
        VStack {
            ScrollView {
                CenteredTitleIconTextView(
                    icon: "server.rack",
                    description: "CellGuard can check for updates in the background. For this, CellGuard would establish an internet connection to an external server.",
                    size: 120
                )
            }

            // navigation depends, show sysdiag instructions on non-jailbroken devices
            #if JAILBREAK
            NavigationLink(destination: LocationPermissionView(), tag: 1, selection: $action) {}
            #else
            NavigationLink(destination: SysDiagnoseView(), tag: 1, selection: $action) {}
            #endif

            HStack {
                Toggle(isOn: $agePolicyConfirmation) {
                    Text("I'm over 18 years or older and agree to the privacy policy.")
                }
                .toggleStyle(CheckboxStyle())

                Link(destination: CellGuardURLs.privacyPolicy) {
                    Image(systemName: "link")
                        .font(.system(size: 20))
                }
            }
            .padding(EdgeInsets(top: 2, leading: 10, bottom: 0, trailing: 10))

            HStack {
                // Here, save that the user agreed to enable automatic update checks
                Button {
                    updateCheck = true
                    self.action = 1
                } label: {
                    Text("Check for Updates")
                }
                .buttonStyle(SmallButtonStyle())
                .padding(3)
                .disabled(!agePolicyConfirmation)

                // Here, save that the user opted out (currently default)
                Button {
                    updateCheck = false
                    self.action = 1
                } label: {
                    Text("Skip")
                }
                .buttonStyle(SmallButtonStyle())
                .padding(3)
            }
            .padding(EdgeInsets(top: 2, leading: 10, bottom: 6, trailing: 10))
        }
        .navigationTitle("Check for Updates")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationView {
        NotificationPermissionView()
    }
}
