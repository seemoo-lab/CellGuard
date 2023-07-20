//
//  CellGuardAppDelegate.swift
//  CellGuard
//
//  Created by Lukas Arnold on 02.01.23.
//

import BackgroundTasks
import Foundation
import OSLog
import UIKit

class CellGuardAppDelegate : NSObject, UIApplicationDelegate {
    
    // https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-an-appdelegate-to-a-swiftui-app
    // https://www.fivestars.blog/articles/app-delegate-scene-delegate-swiftui/
    // https://holyswift.app/new-backgroundtask-in-swiftui-and-how-to-test-it/
    
    static let cellRefreshTaskIdentifier = "de.tudarmstadt.seemoo.CellGuard.refresh.cells"
    static let packetRefreshTaskIdentifier = "de.tudarmstadt.seemoo.CellGuard.refresh.packets"
    static let verifyTaskIdentifier = "de.tudarmstadt.seemoo.CellGuard.processing.verify"
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CellGuardAppDelegate.self)
    )
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Assign our own scene delegate to every scene
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = CellGuardSceneDelegate.self
        return sceneConfig
    }
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        assignNotificationCenterDelegate()
        trackLocationIfBackground(launchOptions)
        registerSchedulers()
        
        if !isTestRun {
            startTasks()
        }
        
        return true
    }
    
    private func trackLocationIfBackground(_ launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) {
        // Only initialize the location manager if the app was explicitly launched in the background to track locations.
        // Otherwise it was initialized in CellGuardApp as environment variable
        if let launchOptions = launchOptions {
            // https://developer.apple.com/documentation/corelocation/cllocationmanager/1423531-startmonitoringsignificantlocati
            if launchOptions[.location] != nil {
                // TODO: Is it even required to start a separate LocationDataManger()?
                // -> I guess not
                // _ = LocationDataManager()
            }
        }
    }
    
    private func registerSchedulers() {
        // Register a background refresh task to poll the tweak continuously in the background
        // https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background/using_background_tasks_to_update_your_app
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.cellRefreshTaskIdentifier, using: nil) { task in
            // Use to cancel operations:
            // let queue = OperationQueue()
            // queue.maxConcurrentOperationCount = 1
            // https://medium.com/snowdog-labs/managing-background-tasks-with-new-task-scheduler-in-ios-13-aaabdac0d95b
            
            let collector = CCTCollector(client: CCTClient(queue: DispatchQueue.global()))
            
            // TODO: Should we allow to cancel the task somehow?
            // task.expirationHandler
            
            collector.collectAndStore { result in
                let count = try? result.get()
                task.setTaskCompleted(success: count != nil)
            }
        }
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.packetRefreshTaskIdentifier, using: nil) { task in
            let collector = CPTCollector(client: CPTClient(queue: DispatchQueue.global()))
            
            collector.collectAndStore { result in
                let count = try? result.get()
                task.setTaskCompleted(success: count != nil)
            }
            
            collector.collectAndStore { result in
                let count = try? result.get()
                task.setTaskCompleted(success: count != nil)
            }
        }
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.verifyTaskIdentifier, using: nil) { task in
            // Simply start our collection & verification tasks
            // TODO: This could be improved by directly rescheduling a task when it has finished
            self.startTasks()
        }
    }
    
    private func startTasks() {
        let cellCollector = CCTCollector(client: CCTClient(queue: .global(qos: .default)))
        
        // Schedule a timer to continuously poll the latest cells while the app is active and instantly verify them
        let cellCollectTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { timer in
            self.collectCellsTask(collector: cellCollector)
        }
        // We allow the timer a high tolerance of 50% as our collector is not time critical
        cellCollectTimer.tolerance = 30
        // We also start the function instantly to fetch the latest cells
        DispatchQueue.global(qos: .default).async {
            self.collectCellsTask(collector: cellCollector)
        }
        
        let packetCollector = CPTCollector(client: CPTClient(queue: .global(qos: .default)))
        
        // TODO: Variable timeout based on whether a the app is open or not
        // Schedule a timer to continuously poll the latest packets while the app is active
        let packetCollectTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { timer in
            self.collectPacketsTask(collector: packetCollector)
        }
        // We allow the timer a tolerance of 50% as our collector is not time critical
        packetCollectTimer.tolerance = 15
        // We also start the function instantly to fetch the latest cells
        DispatchQueue.global(qos: .default).async {
            self.collectPacketsTask(collector: packetCollector)
        }
        
        // Verify collected cells in the background, we start a new detached task for that
        // See: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Unstructured-Concurrency
        // TODO: Change UI (i.e. green spinner after the first two phases, remove setting for method selection, risk indicator (use score), cell status (show score))
        Task.detached {
            // When does the loop finishes? The neat thing is, it doesn't :)
            await CellVerifier.verificationLoop()
        }
        
        // TODO: Add notification task which summarizes the untrusted / suspicious cells all five minutes
        // Start it also instantly when running the app
        // Add a new boolean CoreData model field to TweakCell: notified
        // DB Query: notified = false and status == verified and score < ...
        
        // Clear the persistent history cache all five minutes
        let clearHistoryTimer = Timer.scheduledTimer(withTimeInterval: 60 * 5, repeats: true) { timer in
            guard !PersistenceImporter.importActive else { return }
            PersistenceController.shared.cleanPersistentHistoryChanges()
        }
        clearHistoryTimer.tolerance = 30
        
        let clearPacketTimer = Timer.scheduledTimer(withTimeInterval: 60 * 2, repeats: true) { timer in
            guard !PersistenceImporter.importActive else { return }
            let days = UserDefaults.standard.object(forKey: UserDefaultsKeys.packetRetention.rawValue) as? Double ?? 15.0
            PersistenceController.shared.deletePacketsOlderThan(days: Int(days))
        }
        clearPacketTimer.tolerance = 30
        
        // TODO: Add task to regularly delete old ALS cells (>= 90 days) to force a refresh
        // -> Then, also reset the status of the associated tweak cells
    }
    
    private func collectCellsTask(collector: CCTCollector) {
        // Only run tasks when we currently don't manually import any new data
        guard !PersistenceImporter.importActive else { return }
        
        collector.collectAndStore { result in
            do {
                // Get the number of successfully collected & stored cells
                _ = try result.get()
            } catch {
                // Print the error if the task execution was not successful
                Self.logger.warning("Failed to collect & store cells in scheduled timer: \(error)")
            }
        }
    }
    
    private func collectPacketsTask(collector: CPTCollector) {
        // Only run tasks when we currently don't manually import any new data
        guard !PersistenceImporter.importActive else { return }
        
        collector.collectAndStore { result in
            do {
                _ = try result.get()
            } catch {
                // Print the error if the task execution was not successful
                Self.logger.warning("Failed to collect & store packets in scheduled timer: \(error)")
            }
        }
    }
    
    private func assignNotificationCenterDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }
    
}

extension CellGuardAppDelegate: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the notifications even if the app is in foreground
        // See: https://stackoverflow.com/a/37844312
        
        // We'll show the notifications as a banner and put them into the notification list for later review
        // https://stackoverflow.com/a/65963174
        completionHandler([.banner, .list])
    }
    
}
