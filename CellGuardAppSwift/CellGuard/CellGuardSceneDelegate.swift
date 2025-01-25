//
//  CellGuardSceneDelegate.swift
//  CellGuard
//
//  Created by Lukas Arnold on 06.01.23.
//

import BackgroundTasks
import UIKit
import OSLog

class CellGuardSceneDelegate: NSObject, UIWindowSceneDelegate, ObservableObject {
    
    // https://www.fivestars.blog/articles/app-delegate-scene-delegate-swiftui/
    // https://github.com/robertmryan/BGAppRefresh
    
    // https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background/using_background_tasks_to_update_your_app
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CellGuardSceneDelegate.self)
    )
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Update the notification permission when the app is opened again
        CGNotificationManager.shared.updateAuthorizationStatus()
        LocationDataManager.shared.enterForeground()
        
        // Clear all notification when the users opens our app
        // See: https://stackoverflow.com/a/38497700
        CGNotificationManager.shared.clearNotifications()
        
        // Check if profile is installed to correctly show UI
        Task {
            await ProfileTask().run()
        }
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Schedule the background refresh & processing tasks
        scheduleAppRefresh()
        
        // Disable exact location measurement when the app moves in the background
        LocationDataManager.shared.enterBackground()
        
        // Clear the persistent history
        cleanPersistentHistory()
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Detect when the user force-closes our app
        // See: https://developer.apple.com/forums/thread/668595
        
        // ... and notify that this prevents our app from collecting locations in the background.
        if UserDefaults.standard.dataCollectionMode() != .none {
            CGNotificationManager.shared.queueKeepOpenNotification()
        }
    }
    
    private func cleanPersistentHistory() {
        guard !PortStatus.importActive.load(ordering: .relaxed) else {
            return
        }
        PersistenceController.shared.cleanPersistentHistoryChanges()
    }
    
    private func scheduleAppRefresh() {
        // Schedule the background refresh task once the app goes into the background.
        // The task will be executed no earlier than 1 hour from now.
        // This methods is also called once the task was executed in the background and thus, schedules another execution.
        // (Or at least I hope that)
        
        // Only schedule refresh tasks to fetch cells & packets if the jailbroken mode is active
        #if JAILBREAK
        if UserDefaults.standard.dataCollectionMode() == .automatic {
            do {
                let refreshTask = BGAppRefreshTaskRequest(identifier: CellGuardAppDelegate.cellRefreshTaskIdentifier)
                refreshTask.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
                try BGTaskScheduler.shared.submit(refreshTask)
            } catch {
                Self.logger.warning("Could not schedule the app cell refresh task: \(Self.toDescription(taskSchedulerError: error as? BGTaskScheduler.Error)) -> \(error)")
            }
            
            do {
                let refreshTask = BGAppRefreshTaskRequest(identifier: CellGuardAppDelegate.packetRefreshTaskIdentifier)
                refreshTask.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
                try BGTaskScheduler.shared.submit(refreshTask)
            } catch {
                Self.logger.warning("Could not schedule the app packet refresh task: \(Self.toDescription(taskSchedulerError: error as? BGTaskScheduler.Error)) -> \(error)")
            }
        }
        #endif
        
        do {
            let verifyTask = BGProcessingTaskRequest(identifier: CellGuardAppDelegate.verifyTaskIdentifier)
            verifyTask.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 3)
            try BGTaskScheduler.shared.submit(verifyTask)
        } catch {
            Self.logger.warning("Could not schedule the app verify processing task: \(Self.toDescription(taskSchedulerError: error as? BGTaskScheduler.Error)) -> \(error)")
        }
    }
    
    private static func toDescription(taskSchedulerError: BGTaskScheduler.Error?) -> String {
        guard let error = taskSchedulerError else {
            return ""
        }
        
        switch (error) {
        case BGTaskScheduler.Error.notPermitted: return "notPermitted"
        case BGTaskScheduler.Error.tooManyPendingTaskRequests: return "tooManyPendingTaskRequests"
        case BGTaskScheduler.Error.unavailable: return "unavailable"
        default: return "unknwon \(error.errorCode))"
        }
    }
    
}
