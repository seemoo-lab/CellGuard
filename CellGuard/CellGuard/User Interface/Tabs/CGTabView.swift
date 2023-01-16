//
//  TabView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.01.23.
//

import SwiftUI

struct CGTabView: View {
    
    // Summary: shield.fill or exclamationmark.shield.fill
    // Map: map.fill
    // Details: magnifyingglass or chart.bar.fill or cellularbars
    
    @EnvironmentObject var locationManager: LocationDataManager
    @EnvironmentObject var networkAuthorization: LocalNetworkAuthorization
    @EnvironmentObject var notificationManager: CGNotificationManager
    
    // Only show the introduction if it never has been shown before
    @State private var showingIntroduction = !UserDefaults.standard.bool(forKey: UserDefaultsKeys.introductionShown.rawValue)
    @State private var showingSettings = false
    
    var body: some View {
        // If the introduction already was shown, we check on every start if we still have accesss to the local network        
        return TabView {
            SummaryView(showSettings: { showingSettings = true })
                .tabItem {
                    Label("Summary", systemImage: "shield.fill")
                }
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
            ListView()
                .tabItem {
                    Label("List", systemImage: "list.bullet")
                }
        }
        .sheet(isPresented: $showingIntroduction) {
            WelcomeSheet {
                self.showingIntroduction = false
                
                // Only show the introduction sheet once
                UserDefaults.standard.set(true, forKey: UserDefaultsKeys.introductionShown.rawValue)
                
                // Request permissions after the introduction sheet has been closed
                networkAuthorization.requestAuthorization { _ in
                    locationManager.requestAuthorization { _ in
                        notificationManager.requestAuthorization { _ in }
                    }
                }
            }
        }.sheet(isPresented: $showingSettings) {
            SettingsSheet {
                self.showingSettings = false
            }
        }
    }
}

struct CGTabView_Previews: PreviewProvider {
    static var previews: some View {
        CGTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(LocationDataManager(extact: true))
            .environmentObject(LocalNetworkAuthorization(checkNow: true))
            .environmentObject(CGNotificationManager.shared)
    }
}
