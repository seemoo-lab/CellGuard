//
//  ProfileTask.swift
//  CellGuard
//
//  Created by jiska on 25.01.25.
//


import CoreData
import Foundation
import OSLog

enum ProfileInstallState {
    case expiringSoon
    case installed
    case notPresent
}

class ProfileData: ObservableObject {
    static let shared = ProfileData()
    @Published var installDate: Date? = nil
    @Published var installState: ProfileInstallState = .notPresent
}

struct ProfileTask {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ProfileTask.self)
    )
    private static let profilePath = "/private/var/preferences/Logging/Subsystems/com.apple.CommCenter.plist"
    private static let fm = FileManager.init()
    
    @MainActor func run() async {
        if let attributes = try? Self.fm.attributesOfItem(atPath: Self.profilePath),
           let lastMod = attributes[FileAttributeKey(rawValue: "NSFileModificationDate")] as? Date
        {
            ProfileData.shared.installDate = lastMod
            
            // 20 out of 21 days passed, reinstall soon
            let profileInstallDuration: Double = 21
            let days: Double = 24 * 60 * 60
            if ( Date().timeIntervalSince(lastMod) > (profileInstallDuration - 1) * days ) {
                ProfileData.shared.installState = .expiringSoon
            } else {
                ProfileData.shared.installState = .installed
            }
            
            // also notify the user
            CGNotificationManager.shared.queueProfileExpiryNotification(removalDate: lastMod.addingTimeInterval(profileInstallDuration * days))
            
            Self.logger.info("Baseband debug profile was installed at \(lastMod)")
        } else {
            ProfileData.shared.installState = .notPresent
            ProfileData.shared.installDate = nil
            
            Self.logger.info("No debug profile installed!")
        }
        
    }
    
}
