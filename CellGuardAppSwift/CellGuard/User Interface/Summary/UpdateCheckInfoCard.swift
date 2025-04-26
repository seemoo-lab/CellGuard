//
//  UpdateCheckInfoCard.swift
//  CellGuard
//
//  Created by mp on 25.04.25.
//

import SwiftUI
import OSLog

struct UpdateCheckInfoCard: View {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: UpdateCheckInfoCard.self)
    )

    @State private var latestReleaseVersion = ""

    var body: some View {
        Group {
            if !latestReleaseVersion.isEmpty {
                UpdateCard(latestReleaseVersion: latestReleaseVersion)
            } else {
                // We use a hidden rectangle instead of an EmptyView, as onAppear is not being called for the latter.
                Rectangle().hidden()
            }
        }
        .onAppear {
            Task.detached(priority: .background) {
                await checkForUpdate()
            }
        }
    }

    private func checkForUpdate() async {
        // Verify that the user has enabled the update check
        guard UserDefaults.standard.bool(forKey: UserDefaultsKeys.updateCheck.rawValue) else {
            self.latestReleaseVersion = ""
            return
        }

        guard let majorVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let minorVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            Self.logger.error("Could not parse the current version Info")
            return
        }
        let currentAppVersion = "\(majorVersion) (\(minorVersion))"

        do {
            let (data, _) = try await URLSession.shared.data(from: CellGuardURLs.updateCheck)

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                Self.logger.warning("Response data could not be parsed")
                return
            }

            guard let latestReleaseVersion = json["name"] as? String else {
                Self.logger.warning("Release name could not be parsed")
                return
            }

            if currentAppVersion != latestReleaseVersion {
                self.latestReleaseVersion = latestReleaseVersion
            }
        } catch {
            Self.logger.warning("Request error: \(error.localizedDescription)")
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
