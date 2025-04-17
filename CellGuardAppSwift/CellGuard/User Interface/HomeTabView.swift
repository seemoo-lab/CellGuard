//
//  HomeTabView.swift
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

struct HomeTabView: View {

    var body: some View {
        if #available(iOS 15, *) {
            HomeTabViewIOS15()
        } else {
            HomeTabViewIOS14()
        }
    }

}

@available(iOS 15, *)
private struct HomeTabViewIOS15: View {

    @AppStorage(UserDefaultsKeys.introductionShown.rawValue) var introductionShown: Bool = false

    @State private var showingTab = ShownTab.summary
    @State private var showingSheet: ShownSheet?

    var body: some View {
        CompositeTabView(shownTab: $showingTab, shownSheet: $showingSheet)
            .sheet(item: $showingSheet) { (sheet: ShownSheet) in
                switch sheet {
                case let .importFile(url):
                    NavigationView {
                        ImportView(fileUrl: url)
                    }
                }
            }
            .fullScreenCover(isPresented: Binding(get: {
                !introductionShown
            }, set: { _ in
                // Ignore the change
            })) {
                IntroductionView()
            }
    }
}

// Multiple .sheet() & .fullScreenCover() statements on a single view are not supported in iOS 14
// See: https://stackoverflow.com/a/63181811
// See: https://www.hackingwithswift.com/forums/swiftui/using-sheet-and-fullscreencover-together/4258/13585
private struct HomeTabViewIOS14: View {

    @AppStorage(UserDefaultsKeys.introductionShown.rawValue) var introductionShown: Bool = false

    @State private var shownTab = ShownTab.summary
    @State private var shownSheet: ShownSheet?

    var body: some View {
        ZStack {
            EmptyView()
                .sheet(item: $shownSheet) { (sheet: ShownSheet) in
                    switch sheet {
                    case let .importFile(url):
                        NavigationView {
                            ImportView(fileUrl: url)
                        }
                    }
                }

            CompositeTabView(shownTab: $shownTab, shownSheet: $shownSheet)
                .fullScreenCover(isPresented: Binding(get: {
                    !introductionShown
                }, set: { _ in
                    // Ignore the change
                })) {
                    IntroductionView()
                }
        }
    }

}

private struct CompositeTabView: View {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CompositeTabView.self)
    )

    @Binding var shownTab: ShownTab
    @Binding var shownSheet: ShownSheet?

    var body: some View {
        TabView(selection: $shownTab) {
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
        .onOpenURL { url in
            Self.logger.debug("Open URL: \(url)")

            // Switch to the summary tab and close the shown sheet (if there's any)
            self.shownTab = .summary
            self.shownSheet = nil

            // Wait a bit so the sheet can close and we can present the alert
            // See: https://stackoverflow.com/a/71638878
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.shownSheet = ShownSheet.importFile(url)
            }
        }
    }

}

struct CompositeTabView_Previews: PreviewProvider {
    static var previews: some View {
        HomeTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
