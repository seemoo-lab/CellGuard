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
    @EnvironmentObject var navigator: NavigationRouter

    var body: some View {
        VStack {
            ScrollView {
                CenteredTitleIconTextView(
                    icon: "server.rack",
                    description: "CellGuard can check for updates in the background. If enabled, CellGuard establishes a connection via the Internet to our server.",
                    size: 120
                )
            }

            HStack {
                Toggle(isOn: $agePolicyConfirmation) {
                    Text("I agree to the privacy policy.")
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
                    next()
                } label: {
                    Text("Enable")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)
                .padding(3)
                .disabled(!agePolicyConfirmation)

                // Here, save that the user opted out (currently default)
                Button {
                    updateCheck = false
                    next()
                } label: {
                    Text("Skip")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)
                .padding(3)
            }
            .padding(EdgeInsets(top: 2, leading: 10, bottom: 6, trailing: 10))
        }
        .navigationTitle("Check for Updates")
        .navigationBarTitleDisplayMode(.large)
    }

    func next() {
        #if JAILBREAK
        navigator.push(IntroductionState.location)
        #else
        navigator.push(IntroductionState.systemDiagnose)
        #endif
    }
}

#Preview {
    CGNavigationStack {
        NotificationPermissionView()
            .navigationDestination(for: IntroductionState.self) { _ in
                Text("No")
            }
    }
}
