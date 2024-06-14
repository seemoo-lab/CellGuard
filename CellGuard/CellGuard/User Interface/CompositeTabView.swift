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

private enum ShownSheet: Hashable, Identifiable {
    case importFile(URL)

    var id: Self {
        return self
    }
}

struct CompositeTabView: View {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CompositeTabView.self)
    )
    
    @AppStorage(UserDefaultsKeys.introductionShown.rawValue) var introductionShown: Bool = false
    
    @State private var showingTab = ShownTab.summary
    @State private var showingSheet: ShownSheet?
    
    var body: some View {
        // If the introduction already was shown, we check on every start if we still have access to the local network
        TabView(selection: $showingTab) {
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
            // The tab bar on iOS 15 and above is by default translucent.
            // However in the map tab, it doesn't switch from the transparent to its opaque mode.
            // Therefore, we keep the tab for now always opaque.
            CGTabBarAppearance.opaque()
        }
        // Multiple .sheet() statements on a single view are not supported in iOS 14
        // See: https://stackoverflow.com/a/63181811
        .sheet(item: $showingSheet) { (sheet: ShownSheet) in
            switch (sheet) {
            case let .importFile(url):
                NavigationView {
                    ImportView(fileUrl: url)
                }
            }
        }
        .fullScreenCover(isPresented: Binding(get: {
            !introductionShown
        }, set: { Bool in
            // Ignore the change
        })) {
            IntroductionView()
        }
        .onOpenURL { url in
            Self.logger.debug("Open URL: \(url)")
            
            // Switch to the summary tab and close the shown sheet (if there's any)
            self.showingTab = .summary
            self.showingSheet = nil
            
            // Wait a bit so the sheet can close and we can present the alert
            // See: https://stackoverflow.com/a/71638878
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showingSheet = ShownSheet.importFile(url)
            }
        }
    }
}

struct CompositeTabView_Previews: PreviewProvider {
    static var previews: some View {
        CompositeTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
