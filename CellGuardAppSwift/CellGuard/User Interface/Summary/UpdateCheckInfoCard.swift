//
//  UpdateCheckInfoCard.swift
//  CellGuard
//
//  Created by mp on 25.04.25.
//

import SwiftUI
import OSLog

struct UpdateCheckInfoCard: View {
    @StateObject private var updateData = CheckUpdateData.shared

    var body: some View {
        if let version = updateData.latestReleaseVersion {
            UpdateCard(latestReleaseVersion: version)
        } else {
            EmptyView()
        }
    }
}

private struct UpdateCard: View {

    let latestReleaseVersion: String

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openURL(CellGuardURLs.changelog)
        } label: {
            VStack {
                HStack {
                    Text("Update Available")
                        .font(.title2)
                        .bold()
                    Spacer()
                    Image(systemName: "chevron.right.circle.fill")
                        .imageScale(.large)
                }

                HStack(spacing: 0) {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.blue)
                        .font(Font.custom("SF Pro", fixedSize: 30))
                        .frame(maxWidth: 40, alignment: .center)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 10))

                    Text("CellGuard \(self.latestReleaseVersion) is now available.")
                    .padding()
                    .multilineTextAlignment(.leading)
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
}

#Preview {
    UpdateCheckInfoCard()
}
