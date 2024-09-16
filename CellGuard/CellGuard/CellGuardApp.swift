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
    @Environment(\.scenePhase) var scenePhase
    
    @StateObject var backgroundState = BackgroundState.shared

    var body: some Scene {
        WindowGroup {
            HomeTabView()
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .onChange(of: scenePhase) { backgroundState.update(from: $0) }
                .onAppear { backgroundState.update(from: scenePhase) }
        }
    }
}
