//
//  OpenSysdiagnoseSettings.swift
//  CellGuard
//
//  Created by Lukas Arnold on 21.12.23.
//

import SwiftUI

struct NoneModeCard: View {

    @AppStorage(UserDefaultsKeys.appMode.rawValue) var appMode: DataCollectionMode = .none

    var body: some View {
        if appMode == .none {
            NoneModeCardView()
        } else {
            EmptyView()
        }
    }

    static func openSysdiagnoses() {

    }

}

private struct NoneModeCardView: View {

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack {

            HStack {
                Text("Data Collection Disabled")
                    .font(.title2)
                    .bold()
                Spacer()
                Image(systemName: "exclamationmark.circle.fill")
                    .imageScale(.large)
            }

            HStack(spacing: 0) {
                Image(systemName: "location")
                    .foregroundColor(.blue)
                    .font(Font.custom("SF Pro", fixedSize: 30))
                    .frame(maxWidth: 40, alignment: .center)
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 10))

                Text("CellGuard is running without data collection enabled. To analyze your own data, change the data collection mode to \"Manual\" and provide location access.")
                    .multilineTextAlignment(.leading)
                    .padding()
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
