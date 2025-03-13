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
        if authorizationStatus == .denied {
            completion(false)
            return
        }
        
        if authorizationStatus == .authorized {
            completion(true)
            return
        }
        
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
    
    func queueCellNotification() {
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
        content.title = counts.untrusted > 0 ? "Found Suspicious Cells" : "Found Anomalous Cells"
        content.sound = counts.untrusted > 0 ? .default : nil
        
        var body = "Your iPhone recently connected to "
        if counts.untrusted > 0 && counts.suspicious > 0 {
            body.append("\(counts.untrusted) suspicious and \(counts.suspicious) anomalous cell" + ((counts.untrusted + counts.suspicious != 1 ? "s" : "")))
        } else if counts.untrusted > 0 {
            body.append("\(counts.untrusted) suspicious cell" + (counts.untrusted != 1 ? "s" : ""))
        } else {
            body.append("\(counts.suspicious) anomalous cell" + (counts.suspicious != 1 ? "s" : ""))
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
    
    func queueKeepOpenNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Keep CellGuard running"
        content.sound = nil
        content.body = "CellGuard works in the background to collect location data used to verify cells."
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Self.logger.warning("Failed to schedule keep open notification: \(error)")
            }
        }
    }
    
    func queueProfileExpiryNotification(removalDate: Date) {
        let notificationCenter = UNUserNotificationCenter.current()
        
        // Unique identifier for the notification
        // A previously scheduled notification will be automatically replaced
        let identifier = "profile-expiry"
        
        // Set the notification content
        // TODO: Deep link to profile install view
        let content = UNMutableNotificationContent()
        content.sound = nil
        
        // The notification should appear one day before the profile expiry
        let trigger: UNCalendarNotificationTrigger?
        let calendar = Calendar.current
        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: removalDate) else {
            Self.logger.warning("Failed to calculate day before profile expiry \(removalDate)")
            return
        }
        
        if dayBefore > Date() {
            // If there is still more than one day left, queue the notification
            content.title = "Baseband profile expires tomorrow"
            content.body = "The baseband debug profile expires in one day, reinstall it to continue collecting data."
            
            let dayBeforeComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .timeZone], from: dayBefore)
            trigger = UNCalendarNotificationTrigger(dateMatching: dayBeforeComponents, repeats: false)
        } else {
            // Do not queue another notification if there was already a (scheduled) notification
            let pastNotifyRemovalDate = UserDefaults.standard.date(forKey: UserDefaultsKeys.profileExpiryNotification.rawValue)
            if let pastNotifyRemovalDate = pastNotifyRemovalDate, pastNotifyRemovalDate == removalDate {
                return
            }
            
            // If not, send it instantly
            content.title = "Baseband profile expires soon"
            content.body = "The baseband debug profile expires soon, reinstall it to continue collecting data."
            
            trigger = nil
        }
        
        // Store that a notification is queue or was sent
        UserDefaults.standard.set(removalDate, forKey: UserDefaultsKeys.profileExpiryNotification.rawValue)
        
        // Schedule a new notification
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        notificationCenter.add(request) { error in
            if let error = error {
                Self.logger.warning("Failed to schedule profile expiry notification: \(error)")
            }
        }
    }
    
    func queueProfileInstallNotification(update: Bool) {
        let notificationCenter = UNUserNotificationCenter.current()
        
        // Unique identifier for the notification
        // A previously scheduled notification will be automatically replaced
        let identifier = "profile-install"
        
        // Set the notification content
        let content = UNMutableNotificationContent()
        content.sound = nil
        
        content.title = "Baseband profile " + (update ? "updated" : "installed")
        content.body = "The baseband debug profile was successfully " + (update ? "updated" : "installed") + "."
        
        // Schedule a new notification
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        notificationCenter.add(request) { error in
            if let error = error {
                Self.logger.warning("Failed to schedule profile install notification: \(error)")
            }
        }
    }
    
    func clearNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
}
