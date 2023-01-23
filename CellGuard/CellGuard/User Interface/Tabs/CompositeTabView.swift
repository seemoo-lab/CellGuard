//
//  TabView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.01.23.
//

import SwiftUI

private enum ShownSheet: Identifiable {
    case welcome
    case settings

    var id: Self {
        return self
    }
}

struct CompositeTabView: View {
    
    // Summary: shield.fill or exclamationmark.shield.fill
    // Map: map.fill
    // Details: magnifyingglass or chart.bar.fill or cellularbars
    
    @EnvironmentObject var locationManager: LocationDataManager
    @EnvironmentObject var networkAuthorization: LocalNetworkAuthorization
    @EnvironmentObject var notificationManager: CGNotificationManager
    
    @State private var showingSheet: ShownSheet?
    
    var body: some View {
        // If the introduction already was shown, we check on every start if we still have accesss to the local network
        return TabView {
            SummaryTabView(showSettings: { showingSheet = .settings })
                .tabItem {
                    Label("Summary", systemImage: "shield.fill")
                }
            MapTabView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
            ListTabView()
                .tabItem {
                    Label("List", systemImage: "list.bullet")
                }
        }
        // Multiple .sheet() statements on a single view are not supported in iOS 14
        // See: https://stackoverflow.com/a/63181811
        .sheet(item: $showingSheet) { (sheet: ShownSheet) in
            switch (sheet) {
            case .welcome:
                WelcomeSheet {
                    self.showingSheet = nil
                    
                    // Only show the introduction sheet once
                    UserDefaults.standard.set(true, forKey: UserDefaultsKeys.introductionShown.rawValue)
                    
                    // Request permissions after the introduction sheet has been closed
                    networkAuthorization.requestAuthorization { _ in
                        locationManager.requestAuthorization { _ in
                            notificationManager.requestAuthorization { _ in }
                        }
                    }
                }
            case .settings:
                SettingsSheet {
                    self.showingSheet = nil
                }
                .environmentObject(self.locationManager)
                .environmentObject(self.networkAuthorization)
                .environmentObject(self.notificationManager)
            }
        }
        .onAppear {
            // Only show the introduction if it never has been shown before
            if !UserDefaults.standard.bool(forKey: UserDefaultsKeys.introductionShown.rawValue) {
                showingSheet = .welcome
            }
        }
    }
}

struct CGTabView_Previews: PreviewProvider {
    static var previews: some View {
        CompositeTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(LocationDataManager.shared)
            .environmentObject(LocalNetworkAuthorization(checkNow: true))
            .environmentObject(CGNotificationManager.shared)
    }
}
