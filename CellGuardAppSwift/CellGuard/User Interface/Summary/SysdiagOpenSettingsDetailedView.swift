//
//  SysdiagInstructionsDetailedView.swift
//  CellGuard
//
//  Created by jiska on 20.05.24.
//

import SwiftUI

struct SysdiagOpenSettingsDetailedView: View {
    var body: some View {
        ScrollView {
            Text("Import a Sysdiagnose")
                .font(.title)
                .fontWeight(.bold)
                .padding()
                .multilineTextAlignment(.center)

            Spacer()

            Text("Please follow these steps to import\na sysdiagnose into CellGuard:")
                .multilineTextAlignment(.center)

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

            Spacer(minLength: 40)

            LargeButton(title: "Go to Settings", backgroundColor: .blue) {
                // See: https://github.com/FifiTheBulldog/ios-settings-urls/blob/master/settings-urls.md

                #if JAILBREAK
                // Apple does not like this URL as it accesses a private API (https://stackoverflow.com/a/70838268)
                let url = "App-prefs:Privacy&path=PROBLEM_REPORTING"
                #else
                // The App-Store-Safe-URL
                let url = UIApplication.openSettingsURLString
                #endif

                if let appSettings = URL(string: url), UIApplication.shared.canOpenURL(appSettings) {
                    UIApplication.shared.open(appSettings)
                }
            }
            .padding()

        }
    }
}

#Preview {
    SysdiagOpenSettingsDetailedView()
}
