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

class CellGuardAppDelegate: NSObject, UIApplicationDelegate {

    // https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-an-appdelegate-to-a-swiftui-app
    // https://www.fivestars.blog/articles/app-delegate-scene-delegate-swiftui/
    // https://holyswift.app/new-backgroundtask-in-swiftui-and-how-to-test-it/

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

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        assignNotificationCenterDelegate()
        trackLocationIfBackground(launchOptions)
        registerSchedulers()

        if !isTestRun {
            startTasks()
        }

        return true
    }

    private func trackLocationIfBackground(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) {
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

        #if JAILBREAK
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.packetRefreshTaskIdentifier, using: nil) { task in
            // Only collect cells in the background if the app runs on a jailbroken device
            if UserDefaults.standard.dataCollectionMode() != DataCollectionMode.automatic {
                task.setTaskCompleted(success: true)
                return
            }

            let collector = CPTCollector(client: CPTClient(queue: DispatchQueue.global()))

            Task {
                let count = try? await collector.collectAndStore()
                task.setTaskCompleted(success: count != nil)
            }
        }
        #endif

        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.verifyTaskIdentifier, using: nil) { _ in
            // Simply start our collection & verification tasks
            // TODO: This could be improved by directly rescheduling a task when it has finished
            self.startTasks()
        }
    }

    private func startTasks() {
        Task.detached(priority: .background) {
            // Delay the initialization by 250ms
            try? await Task.sleep(nanoseconds: UInt64(250 * MSEC_PER_SEC))

            #if JAILBREAK
            let packetCollector = CPTCollector(client: CPTClient(queue: .global(qos: .background)))
            let collectPacketsTask: () async -> Void = {
                // Only run the task if the jailbreak mode is active
                guard UserDefaults.standard.dataCollectionMode() == .automatic else { return }

                // Only run the task when we currently don't manually import any new data
                guard !PortStatus.importActive.load(ordering: .relaxed) else { return }

                do {
                    _ = try await packetCollector.collectAndStore()
                } catch {
                    // Print the error if the task execution was not successful
                   await Self.logger.warning("Failed to collect & store packets in scheduled timer: \(error)")
                }
            }
            // Schedule a timer to continuously poll the latest packets
            Task {
                while true {
                    await collectPacketsTask()
                    do {
                        try await Task.sleep(nanoseconds: 15 * NSEC_PER_SEC)
                    } catch {
                        await Self.logger.warning("Failed to sleep after collecting packets: \(error)")
                    }
                }
             }
            #endif

            // This task sends a summary notification all two minutes if any untrusted or suspicious cells have been found
            Task {
                try? await Task.sleep(nanoseconds: 30 * NSEC_PER_SEC)
                while true {
                    guard !PortStatus.importActive.load(ordering: .relaxed) else {
                        try? await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
                        continue
                    }
                    CGNotificationManager.shared.queueCellNotification()
                    try? await Task.sleep(nanoseconds: 2 * 60 * NSEC_PER_SEC)
                }
            }

            // Clear the persistent history cache every minute after a start delay of one minute
            Task {
                try? await Task.sleep(nanoseconds: 60 * NSEC_PER_SEC)
                while true {
                    guard !PortStatus.importActive.load(ordering: .relaxed) else {
                        try? await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
                        continue
                    }
                    PersistenceController.shared.cleanPersistentHistoryChanges()
                    try? await Task.sleep(nanoseconds: 60 * NSEC_PER_SEC)
                }
            }

            // Delete packets older than a given amount of days as configured by the user
            Task {
                try? await Task.sleep(nanoseconds: 90 * NSEC_PER_SEC)
                while true {
                    // Only run the task if the analysis mode is not active
                    guard UserDefaults.standard.dataCollectionMode() != .none else { return }

                    guard !PortStatus.importActive.load(ordering: .relaxed) else {
                        try? await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
                        continue
                    }

                    let days = UserDefaults.standard.object(forKey: UserDefaultsKeys.packetRetention.rawValue) as? Double ?? 3.0

                    // Don't delete packets if the retention time frame is set to infinite
                    if await days < DeleteView.packetRetentionInfinite {
                        PersistenceController.shared.deletePacketsOlderThan(days: Int(days))
                    }

                    try? await Task.sleep(nanoseconds: 5 * 60 * NSEC_PER_SEC)
                }
            }

            // Delete locations older than a given amount of days as configured by the user
            Task {
                try? await Task.sleep(nanoseconds: 60 * NSEC_PER_SEC)
                while true {
                    // Only run the task if the analysis mode is not active
                    guard UserDefaults.standard.dataCollectionMode() != .none else { return }

                    guard !PortStatus.importActive.load(ordering: .relaxed) else {
                        try? await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
                        continue
                    }

                    let days = UserDefaults.standard.object(forKey: UserDefaultsKeys.locationRetention.rawValue) as? Double ?? 7.0

                    // Don't delete locations if the retention time frame is set to infinite
                    if await days < DeleteView.locationRetentionInfinite {
                        PersistenceController.shared.deleteLocationsOlderThan(days: Int(days))
                    }

                    try? await Task.sleep(nanoseconds: 5 * 60 * NSEC_PER_SEC)
                }
            }

            // TODO: Add maintenance task for verifications (delete verification without cells, create verifications for cells without one)

            // Send samples & weekly measurements to backend
            Task {
                try? await Task.sleep(nanoseconds: 15 * NSEC_PER_SEC)
                let task = StudyTask()
                while true {
                    do {
                        try await task.run()
                    } catch {
                        await Self.logger.warning("Upload task failed with error: \(error)")
                    }
                    try? await Task.sleep(nanoseconds: 60 * NSEC_PER_SEC)
                }
            }

            // Check if when debug profile will expire
            Task {
                let task = ProfileTask()
                // try? await Task.sleep(nanoseconds: 15 * NSEC_PER_SEC)
                while true {
                    await task.run()
                    try? await Task.sleep(nanoseconds: 60 * NSEC_PER_SEC)
                }
            }

            Task {
                try? await Task.sleep(nanoseconds: 15 * NSEC_PER_SEC)

                var task = SysdiagTask()
                var lastScreenshotTaken: Date?
                var currentSleepTask: Task<Void, Never>?

                // Increase the Task frequency after an Screenshot
                NotificationCenter.default.addObserver(
                    forName: UIApplication.userDidTakeScreenshotNotification,
                    object: nil,
                    queue: OperationQueue.main
                ) { _ in
                    lastScreenshotTaken = Date()
                    currentSleepTask?.cancel()
                }

                func didScreenshotRecently(_ lastScreenshotTaken: Date?) -> Bool {
                    // We expect that the in-progress sysdiagnose directory is created within 15s after the screenshot, if at all.
                    let sysdiagnoseCreationDelay: TimeInterval = 15
                    guard let last = lastScreenshotTaken else {
                        return false
                    }
                    return Date().timeIntervalSince(last) < sysdiagnoseCreationDelay
                }

                func sleepInterval(_ lastScreenshotTaken: Date?) -> UInt64 {
                    let longInterval = 15 * NSEC_PER_SEC
                    let shortInterval = 1 * NSEC_PER_SEC
                    return didScreenshotRecently(lastScreenshotTaken) ? shortInterval : longInterval
                }

                while true {
                    await task.run(didScreenshotRecently: didScreenshotRecently(lastScreenshotTaken))

                    currentSleepTask = Task {
                        try? await Task.sleep(nanoseconds: sleepInterval(lastScreenshotTaken))
                    }
                    await currentSleepTask?.value
                }
            }

            Task {
                try? await Task.sleep(nanoseconds: 3 * NSEC_PER_SEC)
                let task = UpdateCheckTask()
                while true {
                    await task.run()
                    try? await Task.sleep(nanoseconds: 3 * 3600 * NSEC_PER_SEC)
                }
            }

            await Self.logger.debug("Started all maintenance background tasks")

            // TODO: Add task to regularly delete old ALS cells (>= 90 days) to force a refresh
            // -> Then, also reset the status of the associated tweak cells
        }

        // Verify collected cells in the background, we start a new detached task for that.
        // It's important that we specify a priority, otherwise this task ends up blocking the UI
        // See: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Unstructured-Concurrency
        Task.detached(priority: .background) {
            // Delay the initialization by 500ms
            try? await Task.sleep(nanoseconds: UInt64(500 * MSEC_PER_SEC))

            for pipeline in activeVerificationPipelines {
                Task {
                    // When does the loop finishes? The neat thing is, it doesn't :)
                    await pipeline.run()
                }
            }

            await Self.logger.debug("Started all verification background tasks")
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

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tapped by the user
        // https://stackoverflow.com/a/79185555

        let userInfo = response.notification.request.content.userInfo
        if let type = userInfo["type"] as? String,
           type == "sysdiag",
           let fileName = (userInfo["fileName"] as? String) {
            SysdiagUrls.open(sysdiagnose: fileName)
        }

        completionHandler()
    }

}
