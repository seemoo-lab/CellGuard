//
//  CellGuardApp.swift
//  CellGuard
//
//  Created by Lukas Arnold on 01.01.23.
//

import SwiftUI

@main
struct CellGuardApp: App {
    @UIApplicationDelegateAdaptor(CellGuardAppDelegate.self) var appDelegate
    
    let persistenceController = PersistenceController.shared
    
    // https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background/using_background_tasks_to_update_your_app

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
