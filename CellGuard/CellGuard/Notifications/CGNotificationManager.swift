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

enum CGNotificationLevel {
    
    case verificationFailure
    case locationWarning(distance: CLLocationDistance)
    case locationFailure(distance: CLLocationDistance)
    
    func title() -> String {
        switch (self) {
        case .verificationFailure: return "Cell Verification Failed"
        case .locationWarning: return "Cell Distance Unusually High"
        case .locationFailure: return "Cell Distance Too High"
        }
    }
    
    func body(cell: TweakCell) -> String {
        let distanceFormatter = MKDistanceFormatter()
        distanceFormatter.unitStyle = .abbreviated
        
        let techFormatter = CellTechnologyFormatter.from(technology: cell.technology)
        
        let cellIdStr = "\(techFormatter.country()): \(cell.country), " +
        "\(techFormatter.network()): \(cell.network), " +
        "\(techFormatter.area()): \(cell.area), " +
        "\(techFormatter.cell()): \(cell.cell)"
                
        var dateStr: String? = nil
        if let collected = cell.collected {
            dateStr = " seen at \(mediumDateTimeFormatter.string(from: collected))"
        }
        
        let cellStr = "\(cell.technology ?? "") cell (\(cellIdStr))\(dateStr ?? "")"
        
        switch (self) {
        case .verificationFailure:
            return "The \(cellStr) could not be found in Apple's database. Therefore, it could be rouge base station."
        case let .locationWarning(distance):
            let distanceStr = distanceFormatter.string(fromDistance: distance)
            return "Your recorded location whilst connected to the \(cellStr) differs significantly (\(distanceStr)) from its location in Apple's database. This could be due to high speed travel."
        case let .locationFailure(distance):
            let distanceStr = distanceFormatter.string(fromDistance: distance)
            return "Your recorded location whilst connected to the \(cellStr) is not plausible with a distance of (\(distanceStr)) to its location in Apple's database. Therefore, the cell could be rouge base station."
        }
    }
    
    func sound() -> UNNotificationSound? {
        switch (self) {
        case .verificationFailure: return .default
        case .locationWarning: return nil
        case .locationFailure: return .default
        }
    }
    
}

class CGNotificationManager: ObservableObject {
    
    static let shared = CGNotificationManager()
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CGNotificationManager.self)
    )
    
    @Published var authorizationStatus: UNAuthorizationStatus? = nil
    
    private init() {
        
    }
    
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
    
    func notifyCell(level: CGNotificationLevel, source: NSManagedObjectID) {
        // https://developer.apple.com/documentation/usernotifications/scheduling_a_notification_locally_from_your_app
        // https://www.hackingwithswift.com/books/ios-swiftui/scheduling-local-notifications
        
        // Set the notification text
        let content = UNMutableNotificationContent()
        content.title = level.title()
        content.sound = level.sound()
        
        let taskContext = PersistenceController.shared.newTaskContext()
        taskContext.performAndWait {
            let cell = taskContext.object(with: source) as? TweakCell
            if let cell = cell {
                content.body = level.body(cell: cell)
            }
        }
        
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
    
}
