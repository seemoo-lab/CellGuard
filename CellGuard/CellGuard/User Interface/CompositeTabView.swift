//
//  TabView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.01.23.
//

import CoreData
import OSLog
import SwiftUI

private enum ShownTab: Identifiable {
    case summary
    case map
    case packets
    
    var id: Self {
        return self
    }
}

private enum ShownSheet: Identifiable {
    case welcome

    var id: Self {
        return self
    }
}

private enum ShownAlert: Hashable, Identifiable {
    case importConfirm(URL)
    case importSuccess(cells: Int, locations: Int, packets: Int)
    case importFailed(String)
    
    var id: Self {
        return self
    }
    
}

struct CompositeTabView: View {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CompositeTabView.self)
    )
    
    @State private var showingTab = ShownTab.summary
    @State private var showingImport = false
    @State private var showingSheet: ShownSheet?
    @State private var showingAlert: ShownAlert?
    
    var body: some View {
        if showingImport {
            // https://swiftwithmajid.com/2021/11/25/mastering-progressview-in-swiftui/
            return AnyView(ProgressView() {
                Text("Importing")
                    .font(.title)
            })
        }
        
        // If the introduction already was shown, we check on every start if we still have access to the local network
        let view = TabView(selection: $showingTab) {
            SummaryTabView()
                .tabItem {
                    Label("Summary", systemImage: "shield.fill")
                }
                .tag(ShownTab.summary)
            MapTabView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(ShownTab.map)
            PacketTabView()
                .tabItem {
                    Label("Packets", systemImage: "shippingbox")
                }
                .tag(ShownTab.packets)
        }
        .onAppear {
            // Only show the introduction if it never has been shown before
            if !UserDefaults.standard.bool(forKey: UserDefaultsKeys.introductionShown.rawValue) {
                showingSheet = .welcome
            }
            
            // The tab bar on iOS 15 and above is by default translucent.
            // However in the map tab, it doesn't switch from the transparent to its opaque mode.
            // Therefore, we keep the tab for now always opaque.
            CGTabBarAppearance.opaque()
        }
        // Multiple .sheet() statements on a single view are not supported in iOS 14
        // See: https://stackoverflow.com/a/63181811
        .sheet(item: $showingSheet) { (sheet: ShownSheet) in
            switch (sheet) {
            case .welcome:
                WelcomeSheet {
                    self.showingSheet = nil
                }
            }
        }
        .onOpenURL { url in
            Self.logger.debug("Open URL: \(url)")
            
            // Switch to the summary tab and close the shown sheet (if there's any)
            self.showingTab = .summary
            self.showingSheet = nil
            
            // Wait a bit so the sheet can close and we can present the alert
            // See: https://stackoverflow.com/a/71638878
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showingAlert = ShownAlert.importConfirm(url)
            }
        }
        .alert(item: $showingAlert) { alert in
            // TODO: Replace with a popup of the new ImportView 
            switch (alert) {
            case let .importConfirm(url):
                return Alert(
                    title: Text("Import Database"),
                    message: Text(
                        "Import the selected CellGuard database? " +
                        "This can result in incorrect analysis. " +
                        "It is advertised to export your local database before."
                    ),
                    primaryButton: .cancel() {
                        showingAlert = nil
                    },
                    secondaryButton: .destructive(Text("Import")) {
                        showingImport = true
                        Self.logger.info("Start import from \(url)")
                        PersistenceImporter.importInBackground(url: url) { result in
                            showingImport = false
                            do {
                                let counts = try result.get()
                                showingAlert = .importSuccess(cells: counts.cells, locations: counts.locations, packets: counts.packets)
                                Self.logger.info("Successfully imported \(counts.cells) cells, \(counts.locations) locations, and \(counts.packets) packets.")
                            } catch {
                                showingAlert = .importFailed(error.localizedDescription)
                                Self.logger.info("Import failed due to \(error)")
                            }
                        }
                        showingAlert = nil
                    }
                )
            case let .importFailed(error):
                return Alert(
                    title: Text("Import Failed"),
                    message: Text(error),
                    dismissButton: .default(Text("OK")) {
                        showingAlert = nil
                    }
                )
            case let .importSuccess(cells, locations, packets):
                return Alert(
                    title: Text("Import Complete"),
                    message: Text("Successfully imported \(cells) cells, \(locations) locations, and \(packets) packets."),
                    dismissButton: .default(Text("OK")) {
                        showingAlert = nil
                    }
                )
            }
        }
        return AnyView(view)
    }
}

struct CompositeTabView_Previews: PreviewProvider {
    static var previews: some View {
        CompositeTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(LocationDataManager.shared)
            .environmentObject(LocalNetworkAuthorization(checkNow: true))
            .environmentObject(CGNotificationManager.shared)
    }
}
