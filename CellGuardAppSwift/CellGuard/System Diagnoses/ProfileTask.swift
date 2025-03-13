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
    case unknown
}

class ProfileData: ObservableObject {
    static let shared = ProfileData()
    @Published var installDate: Date? = nil
    @Published var removalDate: Date? = nil
    @Published var installState: ProfileInstallState = .unknown
    
    func update(modificationDate: Date?) {
        guard let installDate = modificationDate else {
            installDate = nil
            removalDate = nil
            installState = .notPresent
            return
        }
        
        let profileInstallDuration: Double = 21
        let days: Double = 24 * 60 * 60
        
        let removalDate = installDate.addingTimeInterval(profileInstallDuration * days)
        
        // 20 out of 21 days passed, reinstall soon
        if (removalDate.addingTimeInterval(-1 * days) < Date()) {
            installState = .expiringSoon
        } else {
            // Notify the user that the profile installation was successful (and guide them back to CellGuard)
            if installState == .notPresent {
                CGNotificationManager.shared.queueProfileInstallNotification(update: false)
            } else if installState == .expiringSoon {
                CGNotificationManager.shared.queueProfileInstallNotification(update: true)
            } else if installState == .installed && (self.installDate != installDate) {
                CGNotificationManager.shared.queueProfileInstallNotification(update: true)
            }
            
            installState = .installed
        }
        
        // Notify the user one day before the profile's expiry or instantly if it is less than 24h until expiry.
        // This notification will only appear once for the given removal date.
        CGNotificationManager.shared.queueProfileExpiryNotification(removalDate: removalDate)
                
        self.installDate = installDate
        self.removalDate = removalDate
    }
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
            ProfileData.shared.update(modificationDate: lastMod)
            Self.logger.info("Baseband debug profile was installed at \(lastMod)")
        } else {
            ProfileData.shared.update(modificationDate: nil)
            Self.logger.info("No debug profile installed!")
        }
        
    }
    
}
