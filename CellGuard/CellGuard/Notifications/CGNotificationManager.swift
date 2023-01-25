//
//  CGNotifications.swift
//  CellGuard
//
//  Created by Lukas Arnold on 16.01.23.
//

import Foundation
import UserNotifications
import OSLog

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
    
    
}
