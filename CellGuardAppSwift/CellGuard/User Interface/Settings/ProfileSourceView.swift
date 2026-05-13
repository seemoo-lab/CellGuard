//
//  ProfileSourceView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 13.05.26.
//

import SwiftUI

enum ProfileSource: String {
    case cellGuard
    case apple

    var url: URL {
        switch self {
        case .cellGuard: CellGuardURLs.profile
        case .apple: AppleURLs.downloadBasebandProfile
        }
    }
}

struct ProfileSourceView: View {
    @AppStorage(UserDefaultsKeys.profileSource.rawValue) var source: ProfileSource = .cellGuard

    var body: some View {
        List {
            Section(header: Text("Source"), footer: Text("Choose if you want to use a profile mirror, saving you some taps.")) {
                Picker("Select Source", selection: $source) {
                    Text("Apple").tag(ProfileSource.apple)
                    Text("CellGuard").tag(ProfileSource.cellGuard)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileSourceView()
}
