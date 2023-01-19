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
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        scheduleAppRefresh()
    }
    
    private func scheduleAppRefresh() {
        // Scheudle the background refresh task once the app goes into the background.
        // The task will be executed no earlier than 1 hour from now.
        // This methods is also called once the task was executed in the background and thus, schedules another execution.
        // (Or at least I hope that)
        
        do {
            let refreshTask = BGAppRefreshTaskRequest(identifier: CellGuardAppDelegate.cellRefreshTaskIdentifier)
            refreshTask.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
            try BGTaskScheduler.shared.submit(refreshTask)
        } catch {
            Self.logger.warning("Could not schedule the app cell refresh task: \(Self.toDescription(taskSchedulerError: error as? BGTaskScheduler.Error)) -> \(error)")
        }
        
        do {
            let verifyTask = BGProcessingTaskRequest(identifier: CellGuardAppDelegate.verifyTaskIdentifier)
            verifyTask.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 6)
            try BGTaskScheduler.shared.submit(verifyTask)
        } catch {
            Self.logger.warning("Could not schedule the app verify prcessing task: \(Self.toDescription(taskSchedulerError: error as? BGTaskScheduler.Error)) -> \(error)")
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
