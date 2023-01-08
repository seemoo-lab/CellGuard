//
//  CellGuardAppDelegate.swift
//  CellGuard
//
//  Created by Lukas Arnold on 02.01.23.
//

import Foundation
import UIKit
import BackgroundTasks

class CellGuardAppDelegate : NSObject, UIApplicationDelegate {
    
    // https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-an-appdelegate-to-a-swiftui-app
    // https://www.fivestars.blog/articles/app-delegate-scene-delegate-swiftui/
    // https://holyswift.app/new-backgroundtask-in-swiftui-and-how-to-test-it/
    
    static let cellRefreshTaskIdentifier = "de.tu-darmstadt.seemoo.CellGuard.refresh.cells"
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Assign our own scene delegate to every scene
        let scenceConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        scenceConfig.delegateClass = CellGuardSceneDelegate.self
        return scenceConfig
    }
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        if let launchOptions = launchOptions {
            // https://developer.apple.com/documentation/corelocation/cllocationmanager/1423531-startmonitoringsignificantlocati
            if launchOptions[.location] != nil {
                _ = LocationDataManager(extact: false)
            }
        }
        
        
        // Register a background refresh task to poll the tweak continuously in the background
        // https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background/using_background_tasks_to_update_your_app
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.cellRefreshTaskIdentifier, using: nil) { task in
            // Use to cancel operations:
            // let queue = OperationQueue()
            // queue.maxConcurrentOperationCount = 1
            // https://medium.com/snowdog-labs/managing-background-tasks-with-new-task-scheduler-in-ios-13-aaabdac0d95b
            
            let collector = CCTProvider(client: CCTClient(queue: DispatchQueue.global()))
            
            // TODO: Should we allow to cancel the task somehow?
            // task.expirationHandler
            
            collector.collectAndStore { error in
                task.setTaskCompleted(success: error == nil)
            }
        }
                        
        // Notifications? https://www.hackingwithswift.com/books/ios-swiftui/scheduling-local-notifications
        
        return true
    }
    
}
