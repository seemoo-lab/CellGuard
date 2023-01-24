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
    @State private var showingImport: Bool = false
    @State private var importURL: URLIdentfiable? = nil
    
    var body: some View {
        if showingImport {
            // https://swiftwithmajid.com/2021/11/25/mastering-progressview-in-swiftui/
            return AnyView(ProgressView() {
                Text("Importing")
                    .font(.title)
            })
        }
        
        // If the introduction already was shown, we check on every start if we still have accesss to the local network
        return AnyView(TabView {
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
                SettingsSheet { reason in
                    if reason == .delete {
                        self.showingSheet = .welcome
                    } else {
                        self.showingSheet = nil
                    }
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
        .onOpenURL { url in
            importURL = URLIdentfiable(url: url)
        }
        .alert(item: $importURL) { url in
            let url = url.url
            return Alert(
                title: Text("Import Database"),
                message: Text(
                    "Import the selected CellGuard database? " +
                    "This can result in incorrect analysis. " +
                    "It is advertised to export your local database before."
                ),
                primaryButton: .cancel() {
                    importURL = nil
                },
                secondaryButton: .destructive(Text("Import")) {
                    showingImport = true
                    PersistenceImporter.importInBackground(url: url) { result in
                        // TODO: Handle result
                        showingImport = false
                    }
                    importURL = nil
                }
            )
        })
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
