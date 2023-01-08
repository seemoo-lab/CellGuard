//
//  CellGuardSceneDelegate.swift
//  CellGuard
//
//  Created by Lukas Arnold on 06.01.23.
//

import UIKit
import BackgroundTasks

class CellGuardSceneDelegate: NSObject, UIWindowSceneDelegate, ObservableObject {
    
    // https://www.fivestars.blog/articles/app-delegate-scene-delegate-swiftui/
    // https://github.com/robertmryan/BGAppRefresh
    
    // https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background/using_background_tasks_to_update_your_app
    
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
            print("Could not schedule the app cell refresh task: \(toDescription(taskSchedulerError: error as? BGTaskScheduler.Error)) -> \(error)")
        }
    }

    private func toDescription(taskSchedulerError: BGTaskScheduler.Error?) -> String {
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
