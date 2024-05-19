//
//  OpenSysdiagnoseSettings.swift
//  CellGuard
//
//  Created by Lukas Arnold on 21.12.23.
//

import SwiftUI

struct OpenSysdiagnoseSettings: View {
    
    @AppStorage(UserDefaultsKeys.appMode.rawValue) var appMode: DataCollectionMode = .none
    
    var body: some View {
        if appMode == .manual {
            Button {
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
            } label: {
                OpenCard()
            }
        } else {
            EmptyView()
        }
    }
    
    static func openSysdiagnoses() {
        
    }
    
}

private struct OpenCard: View {
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack {
            HStack() {
                Text("Import Sysdiagnose")
                    .font(.title2)
                    .bold()
                Spacer()
                Image(systemName: "chevron.right.circle.fill")
                    .imageScale(.large)
            }
            HStack {
                Text("Open Settings to share data with CellGuard")
                    .multilineTextAlignment(.leading)
                    .padding()
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                .foregroundColor(colorScheme == .dark ? Color(UIColor.systemGray6) : .white)
                .shadow(color: .black.opacity(0.2), radius: 8)
        )
        .foregroundColor(colorScheme == .dark ? .white : .black.opacity(0.8))
        .padding()
    }
    
}
