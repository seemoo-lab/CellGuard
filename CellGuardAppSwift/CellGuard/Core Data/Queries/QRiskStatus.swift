//
//  RiskStatus.swift
//  CellGuard
//
//  Created by Lukas Arnold on 04.05.24.
//

import Foundation
import CoreData

extension PersistenceController {

    func determineDataRiskStatus() -> RiskLevel {
        return (try? performAndWait(name: "fetchContext", author: "determineDataRiskStatus") { context -> RiskLevel in
            let dataCollectionMode = UserDefaults.standard.dataCollectionMode()

            // == Predicates ==
            let calendar = Calendar.current
            let thirtyMinutesAgo = Date() - 30 * 60
            let ftDaysAgo = calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: Date()))!

            // Consider all cells if the analysis mode is active, otherwise only those of the last 14 days
            let ftDayPredicate: NSPredicate
            if dataCollectionMode == .none {
                // This predicate always evaluates to true
                ftDayPredicate = NSPredicate(value: true)
            } else {
                ftDayPredicate = NSPredicate(format: "cell.collected >= %@", ftDaysAgo as NSDate)
            }

            let notFinishedPredicate = NSPredicate(format: "finished == NO")
            let finishedPredicate = NSPredicate(format: "finished == YES")

            let hasCellAssignedPredicate = NSPredicate(format: "cell != nil")
            let primaryVerificationPipelinePredicate = NSPredicate(format: "pipeline == %@", Int(primaryVerificationPipeline.id) as NSNumber)

            // == Sort Descriptors ==
            let sortDescriptor = [NSSortDescriptor(key: "cell.collected", ascending: false)]

            // == Unverified Measurements ==
            let unknownFetchRequest: NSFetchRequest<VerificationState> = VerificationState.fetchRequest()
            unknownFetchRequest.sortDescriptors = sortDescriptor
            unknownFetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                primaryVerificationPipelinePredicate,
                hasCellAssignedPredicate,
                ftDayPredicate,
                notFinishedPredicate
            ])
            unknownFetchRequest.fetchLimit = 1
            let unknowns = try context.fetch(unknownFetchRequest)

            // We show the unknown status if there's work left and were in the analysis mode
            if unknowns.count > 0 && dataCollectionMode == .none {
                return .unknown
            }

            // == Failed Measurements ==
            let failedFetchRequest: NSFetchRequest<VerificationState> = VerificationState.fetchRequest()
            failedFetchRequest.sortDescriptors = sortDescriptor
            failedFetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                primaryVerificationPipelinePredicate,
                hasCellAssignedPredicate,
                ftDayPredicate,
                finishedPredicate,
                NSPredicate(format: "score < %@", primaryVerificationPipeline.pointsUntrusted as NSNumber)
            ])
            let failed = try context.fetch(failedFetchRequest)
            if failed.count > 0 {
                let cellCount = Dictionary(grouping: failed) { Self.queryCell(from: $0.cell!) }.count
                return .high(cellCount: cellCount)
            }

            // == Suspicious Measurements ==
            let suspiciousFetchRequest: NSFetchRequest<VerificationState> = VerificationState.fetchRequest()
            suspiciousFetchRequest.sortDescriptors = sortDescriptor
            suspiciousFetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                primaryVerificationPipelinePredicate,
                hasCellAssignedPredicate,
                ftDayPredicate,
                finishedPredicate,
                NSPredicate(format: "score < %@", primaryVerificationPipeline.pointsSuspicious as NSNumber)
            ])
            let suspicious = try context.fetch(suspiciousFetchRequest)
            if suspicious.count > 0 {
                let cellCount = Dictionary(grouping: suspicious) { Self.queryCell(from: $0.cell!) }.count
                return .medium(cause: .cells(cellCount: cellCount))
            }

            #if JAILBREAK
            // Only check data received from tweaks if the device is jailbroken
            if dataCollectionMode == .automatic {
                // We've received no packets so far from the tweak
                guard let mostRecentPacket = UserDefaults.standard.date(forKey: UserDefaultsKeys.mostRecentPacket.rawValue) else {
                    return .medium(cause: .tweakCells)
                }

                // We've received no packets for 30 minutes from the tweak, so we warn the user
                if mostRecentPacket < thirtyMinutesAgo {
                    return .medium(cause: .tweakCells)
                }
            }
            #endif

            // Only ensure that log collection works if the manual mode is active
            if dataCollectionMode == .manual {
                // == Low Power Mode ==
                // See: https://developer.apple.com/documentation/foundation/processinfo/1617047-islowpowermodeenabled
                if ProcessInfo.processInfo.isLowPowerModeEnabled {
                    return .medium(cause: .lowPowerMode)
                }

                // == Disk Space ==
                // See: https://stackoverflow.com/a/26198164
                let homeURL = URL(fileURLWithPath: NSHomeDirectory() as String, isDirectory: true)
                do {
                    let values = try homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForOpportunisticUsageKey])
                    if let availableCapacity = values.volumeAvailableCapacityForOpportunisticUsage {
                        if availableCapacity < 1024 * 1024 * 1024 {
                            return .medium(cause: .diskSpace)
                        }
                    }
                } catch {
                    logger.warning("Failed to get available disk space for opportunistic usage: \(error)")
                }
            }

            // Only check locations if the data collection is active
            if dataCollectionMode != .none {

                // == Latest Location ==
                let locationFetchRequest: NSFetchRequest<LocationUser> = LocationUser.fetchRequest()
                locationFetchRequest.fetchLimit = 1
                locationFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \LocationUser.collected, ascending: false)]
                let location = try context.fetch(locationFetchRequest)

                // We've received no location for 30 minutes from iOS, so we warn the user
                guard let latestLocation = location.first else {
                    return .medium(cause: .location)
                }
                if latestLocation.collected ?? Date.distantPast < thirtyMinutesAgo {
                    return .medium(cause: .location)
                }
            }

            // == Permissions ==

            if (LocationDataManagerPublished.shared.authorizationStatus ?? .authorizedAlways) != .authorizedAlways ||
                (CGNotificationManager.shared.authorizationStatus ?? .authorized) != .authorized {
                return .medium(cause: .permissions)
            }

            // We keep the unknown status until all cells are verified (except the current cell which we are monitoring)
            // If the analysis mode is not active, we the unknown mode has a lower priority
            if unknowns.count == 1, let unknownCellStatus = unknowns.first, unknownCellStatus.stage >= primaryVerificationPipeline.stageNumberWaitingForPackets {
                return .lowMonitor
            } else if unknowns.count > 0 {
                return .unknown
            }

            return .low

        }) ?? RiskLevel.medium(cause: .cantCompute)
    }

}
