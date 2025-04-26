//
//  SysdiagInstructionsDetailedView.swift
//  CellGuard
//
//  Created by jiska on 20.05.24.
//

import SwiftUI

struct SysdiagOpenSettingsDetailedView: View {
    @AppStorage(UserDefaultsKeys.shortcutInstalled.rawValue)
    private var shortcutInstalled: Bool = false

    var body: some View {
        ScrollView {
            Text("Import a Sysdiagnose")
                .font(.title)
                .fontWeight(.bold)
                .padding()
                .multilineTextAlignment(.center)

            Spacer()

            // CellGuard will notify you once a sysdiagnose is ready to be imported.

            Text("Follow these steps to manually import\na sysdiagnose into CellGuard")
                .multilineTextAlignment(.center)
                .padding()

            Spacer(minLength: 10)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: "gear")
                        .foregroundColor(.blue)
                    Text("Settings ›")
                }
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(.blue)
                    Text("Privacy & Security ›")
                }
                Text("       Analytics and Improvements ›")
                Text("       Analytics Data ›")
                Text("       Scoll Upwards")
                    .foregroundColor(.gray)
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.blue)
                    Text("sysdiag")
                }
                Text("       Select latest sysdiagnose file")
                    .foregroundColor(.gray)
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                    Text("Share with CellGuard app")
                        .foregroundColor(.gray)
                }
            }

            LargeButton(title: "Go to \(shortcutInstalled ? "Analytics Data" : "Settings")", backgroundColor: .blue) {
                SysdiagUrls.open(sysdiagnose: nil)
            }
            .padding()

            VStack {
                Text("You can directly navigate to sysdiagnoses using a Shortcut. Once installed, simply tap CellGuard's ready-to-import notification.")
                    .foregroundColor(.gray)

                Toggle(isOn: .init(get: {
                    shortcutInstalled
                }, set: { state in
                    // Prompt the user to install the shortcut if the setting is enabled
                    // We cannot verify that the shortcut was installed successfully
                    if state {
                        SysdiagUrls.installShortcut()
                    }
                    shortcutInstalled = state
                })) {
                    Text("Shortcut Active")
                }
                .padding()
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    SysdiagOpenSettingsDetailedView()
}
