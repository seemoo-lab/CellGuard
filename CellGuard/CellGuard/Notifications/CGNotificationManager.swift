//
//  CGNotifications.swift
//  CellGuard
//
//  Created by Lukas Arnold on 16.01.23.
//

import CoreData
import MapKit
import UserNotifications
import OSLog

class CGNotificationManager: ObservableObject {
    
    static let shared = CGNotificationManager()
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CGNotificationManager.self)
    )
    
    @Published var authorizationStatus: UNAuthorizationStatus? = nil
    
    private init() { }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if let error = error {
                Self.logger.info("Can't request authorization for notifications: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                if success {
                    self.authorizationStatus = .authorized
                } else {
                    self.authorizationStatus = .denied
                }
                completion(success)
            }
        }
    }
    
    func updateAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    // TODO: Clear notification upon starting CellGuard
    
    func queueNotifications() {
        guard let counts = PersistenceController.shared.fetchNotificationCellCounts() else {
            Self.logger.warning("Couldn't fetch the count of untrusted and suspicious measurements not yet sent as notifications")
            return
        }
        
        if counts.suspicious == 0 && counts.untrusted == 0 {
            // Nothing to notify the user about :)
            return
        }
        
        // https://developer.apple.com/documentation/usernotifications/scheduling_a_notification_locally_from_your_app
        // https://www.hackingwithswift.com/books/ios-swiftui/scheduling-local-notifications
        
        // Set the notification text
        let content = UNMutableNotificationContent()
        content.title = counts.untrusted > 0 ? "Found Untrusted Cells" : "Found Suspicious Cells"
        content.sound = counts.untrusted > 0 ? .default : nil
        
        var body = "Your iPhone recently connected to "
        if counts.untrusted > 0 && counts.suspicious > 0 {
            body.append("\(counts.untrusted) untrusted and \(counts.suspicious) suspicious cell" + ((counts.untrusted != 1 || counts.suspicious != 1 ? "s" : "")))
        } else if counts.untrusted > 0 {
            body.append("\(counts.untrusted) untrusted cell" + (counts.untrusted != 1 ? "s" : ""))
        } else {
            body.append("\(counts.suspicious) suspicious cell" + (counts.suspicious != 1 ? "s" : ""))
        }
        content.body = body
        
        // Build the notification request and instantly deliver the notification (trigger: nil)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        
        Self.logger.debug("Schedule notification with content \(content) and request \(request)")
        
        // Schedule the notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Self.logger.warning("Failed to schedule notification: \(error)")
            }
        }
    }
    
    func clearNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
}
