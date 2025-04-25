//
//  SysdiagTask.swift
//  CellGuard
//
//  Created by Lukas Arnold on 13.03.25.
//

import Foundation
import OSLog

struct SysdiagTask {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: SysdiagTask.self)
    )
    private static let sysdiagnoseDir = "/private/var/mobile/Library/Logs/CrashReporter/DiagnosticLogs/sysdiagnose/"
    private static let fm = FileManager.init()
    private static let formatter = {
        // https://developer.apple.com/documentation/foundation/dateformatter#2528261
        // https://unicode.org/reports/tr35/tr35-dates.html#Date_Format_Patterns
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy.MM.dd_HH-mm-ssZZZ"
        return formatter
    }()
    private static let osBuild =
        ProcessInfo.processInfo.operatingSystemVersionString
        .trimmingCharacters(in: CharacterSet([")"]))
        .split(separator: " ")
        .last

    private var foundSysdiagnoses: Set<Int> = Set()

    @MainActor mutating func run() async {
        // The issue is that sysdiagnoses take multiple minutes to be generated (at max 10).
        // Thus, we have to look back into the future to find sysdiagnoses
        // TODO: Does this use too much resources? -> It takes roughly 100ms
        // TODO: Can we maybe already detect if files are assembled for a sysdiagnose -> Where does iOS store them?

        let now = Date()
        Self.logger.info("Checking for past sysdiagnoses")

        for seconds in 0..<(10 * 60) {
            let captured = now.addingTimeInterval(Double(-seconds))
            let timestamp = Int(captured.timeIntervalSince1970)
            let fileName = await check(forDate: captured)
            if let fileName = fileName, !foundSysdiagnoses.contains(timestamp) {
                CGNotificationManager.shared.queueSysdiagNotification(fileName: fileName, captured: captured)
                foundSysdiagnoses.insert(timestamp)
            }
        }

        Self.logger.info("Finished checking for past sysdiagnoses")
    }

    private func check(forDate date: Date) async -> String? {
        guard let dateString = Self.formatter.string(for: date) else {
            return nil
        }

        guard let osBuild = Self.osBuild, osBuild.count == 5 else {
            return nil
        }

        // sysdiagnose_2025.03.12_18-27-44+0100_iPhone-OS_iPhone_22D82.tar.gz
        // sysdiagnose_year.month.day_hour-minute-second+tz_os_osver.tar.gz
        let fileName = "sysdiagnose_\(dateString)_iPhone-OS_iPhone_\(osBuild).tar.gz"
        let path = Self.sysdiagnoseDir + fileName

        // Self.logger.debug("Checking for sysdiagnose file: \(path)")

        do {
            // This operation will always fail
            try Self.fm.attributesOfItem(atPath: path)
        } catch {
            // But the type of error is interesting for us:

            // Error: Error Domain=NSCocoaErrorDomain Code=257 "The file “sysdiagnose_2025.03.13_18-11-49+0100_iPhone-OS_iPhone_22D82.tar.gz” couldn’t be opened because you don’t have permission to view it." -> Exists
            // Error: Error Domain=NSCocoaErrorDomain Code=260 "The file “sysdiagnose_2025.03.13_18-11-50+0100_iPhone-OS_iPhone_22D82.tar.gz” couldn’t be opened because there is no such file." -> Does not exists

            if (error as NSError).code == 257 {
                Self.logger.debug("Sysdiagnose \(fileName) exists")
                return fileName
            }

            // Self.logger.debug("Error: \(error)")
        }

        return nil
    }
    
    private static let diagnosticsSettingsUrl: String = {
        if #available(iOS 18.0, *) {
            return "settings-navigation://com.apple.Settings.PrivacyAndSecurity/PROBLEM_REPORTING/DIAGNOSTIC_USAGE_DATA"
        } else {
            return "prefs:root=Privacy&path=PROBLEM_REPORTING/DIAGNOSTIC_USAGE_DATA"
        }
    }()
    
    static func settingsUrlFor(sysdiagnose: String?) -> String {
        if let sysdiagnose = sysdiagnose {
            return diagnosticsSettingsUrl + "/" + sysdiagnose
        } else {
            return diagnosticsSettingsUrl
        }
    }

}
