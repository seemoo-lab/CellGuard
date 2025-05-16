//
//  CheckUpdateTask.swift
//  CellGuard
//
//  Created by mp on 04.05.25.
//

import Foundation
import OSLog

class CheckUpdateData: ObservableObject {
    static let shared = CheckUpdateData()
    @Published var latestReleaseVersion: String?
}

struct UpdateCheckTask {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: SysdiagTask.self)
    )

    func run() async {
        // Verify that the user has enabled the update check
        guard UserDefaults.standard.bool(forKey: UserDefaultsKeys.updateCheck.rawValue) else {
            await MainActor.run {
                CheckUpdateData.shared.latestReleaseVersion = nil
            }
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

            guard let releaseName = json["name"] as? String else {
                Self.logger.warning("Release name could not be parsed")
                return
            }

            guard let releaseNameSplit = releaseName.split(separator: ")", maxSplits: 1).first else {
                Self.logger.warning("Release version could not be parsed")
                return
            }
            let latestReleaseVersion = "\(releaseNameSplit))"

            if currentAppVersion != latestReleaseVersion {
                await MainActor.run {
                    CheckUpdateData.shared.latestReleaseVersion = latestReleaseVersion
                }
            }
        } catch {
            Self.logger.warning("Request error: \(error.localizedDescription)")
        }
    }
}
