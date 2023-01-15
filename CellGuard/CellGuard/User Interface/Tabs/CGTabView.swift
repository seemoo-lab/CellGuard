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
    
    @State private var showingIntroduction = true
    @State private var showingSettings = false
    
    var body: some View {
        let showSettings = {
            showingSettings = true
        }
        
        TabView {
            SummaryView(showSettings: showSettings)
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
    }
}
