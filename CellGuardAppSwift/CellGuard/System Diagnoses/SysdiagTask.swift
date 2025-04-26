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

    private var inProgress: Set<Int> = Set()

    @MainActor mutating func run() async {
        let now = Date()
        Self.logger.info("Checking for active sysdiagnoses")

        // We check for system diagnoses which were recently started (the task runs every 30s -> check last 45s)
        for seconds in 0..<25 {
            let captured = now.addingTimeInterval(Double(-seconds))
            let timestamp = Int(captured.timeIntervalSince1970)
            let fileName = await check(forDate: captured, inProgress: true)
            if fileName != nil, !inProgress.contains(timestamp) {
                CGNotificationManager.shared.queueSysdiagStartedNotification(captured: captured)
                inProgress.insert(timestamp)
                Self.logger.info("Found active sysdiagnose: \(captured)")
            }
        }

        Self.logger.info("Checking for past sysdiagnoses")

        // Sysdiagnoses take multiple minutes to be generated (max. 10 minutes)
        for timestamp in inProgress {
            let captured = Date(timeIntervalSince1970: Double(timestamp))
            let fileName = await check(forDate: captured, inProgress: false)
            if let fileName = fileName {
                CGNotificationManager.shared.queueSysdiagReadyNotification(fileName: fileName, captured: captured)
                inProgress.remove(timestamp)
                Self.logger.info("Found completed sysdiagnose: \(captured)")
            }
        }

        Self.logger.info("Finished checking sysdiagnoses")
    }

    private func check(forDate date: Date, inProgress: Bool) async -> String? {
        guard let dateString = Self.formatter.string(for: date) else {
            Self.logger.warning("Cannot format date: \(date)")
            return nil
        }

        guard let osBuild = Self.osBuild, osBuild.count >= 4 else {
            Self.logger.warning("OS build number is too short: \(String(Self.osBuild ?? "nil"))")
            return nil
        }

        // Samples:
        // - IN_PROGRESS_sysdiagnose_2025.04.25_17-57-43+0200_iPhone-OS_iPhone_22D82.tar.gz
        // - sysdiagnose_2025.03.12_18-27-44+0100_iPhone-OS_iPhone_22D82.tar.gz
        // Format:
        // (IN_PROGRESS_)?sysdiagnose_$year.$month.$day_$hour-$minute-$second+$tz_$os_$osver.tar.gz

        let sysdiagName = "sysdiagnose_\(dateString)_iPhone-OS_iPhone_\(osBuild)"

        if inProgress {
            let dirName = "IN_PROGRESS_\(sysdiagName).tmp"
            let path = Self.sysdiagnoseDir + dirName

            // Error Domain=NSCocoaErrorDomain Code=260 "The file “test” couldn’t be opened because there is no such file." UserInfo={NSFilePath=/private/var/mobile/Library/Logs/CrashReporter/DiagnosticLogs/sysdiagnose/test, NSURL=file:///private/var/mobile/Library/Logs/CrashReporter/DiagnosticLogs/sysdiagnose/test, NSUnderlyingError=0x1125dcea0 {Error Domain=NSPOSIXErrorDomain Code=2 "No such file or directory"}} -> Does not exists
            do {
                // This operation will only fail if the directory does not exist
                try Self.fm.attributesOfItem(atPath: path)
            } catch {
                if (error as NSError).code == 260 {
                    // The directory does not exist
                    return nil
                }

                // Self.logger.debug("Error: \(error)")
            }

            // The directory exists
            return dirName
        } else {
            let fileName = "\(sysdiagName).tar.gz"
            let path = Self.sysdiagnoseDir + fileName

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
        }

        return nil
    }

}
