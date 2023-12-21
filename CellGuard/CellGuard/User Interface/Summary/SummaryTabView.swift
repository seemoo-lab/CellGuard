//
//  SummaryView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.01.23.
//

import CoreData
import SwiftUI

// Do not attempt to use a SwiftUI Menu within a NavigationView ToolbarItem!
// This is utterly broken in SwiftUI on iOS 14 as the menu always closes if a view gets any kind of update.
// See:
// - https://developer.apple.com/forums/thread/664906
// - https://stackoverflow.com/questions/68373893/toolbar-menu-is-closed-when-updates-are-made-to-ui-in-swiftui
// - https://www.hackingwithswift.com/forums/swiftui/navigationbar-toolbar-button-not-working-properly/3376
// - https://stackoverflow.com/questions/63540602/navigationbar-toolbar-button-not-working-reliable-when-state-variable-refres
// - https://stackoverflow.com/questions/65095562/observableobject-is-updating-all-views-and-causing-menus-to-close-in-swiftui
//
// We've got a workaround for a related problem with NavigationLinks in ToolbarItems in PacketTabView.swift.
//
// And we've fixed the primary issue with 'Self._printChanges()' (Only works on iOS 15 and above)
// See: WelcomeSheet.swift
// See: https://www.hackingwithswift.com/quick-start/swiftui/how-to-find-which-data-change-is-causing-a-swiftui-view-to-update


struct SummaryTabView: View {
    
    @State private var showingCellList = false
    @State private var showingStats = false
    @State private var showingHelp = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack {
                NavigationLink(isActive: $showingCellList) {
                    CellListView()
                } label: {
                    EmptyView()
                }
                NavigationLink(isActive: $showingStats) {
                    DataSummaryView()
                } label: {
                    EmptyView()
                }

                NavigationLink(isActive: $showingHelp) {
                    Text("TODO")
                } label: {
                    EmptyView()
                }
                NavigationLink(isActive: $showingSettings) {
                    SettingsView()
                } label: {
                    EmptyView()
                }
                CombinedRiskCellView()
            }
            .navigationTitle("Summary")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingCellList = true
                        } label: {
                            Label("Connected Cells", systemImage: "list.bullet")
                        }
                        Button {
                            showingStats = true
                        } label: {
                            Label("Stats", systemImage: "chart.bar.xaxis")
                        }
                        Button {
                            showingHelp = true
                        } label: {
                            Label("Help", systemImage: "questionmark.circle")
                        }
                        Button {
                            showingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .imageScale(.large)
                    }
                }
            }
        }
        .background(Color.gray)
    }
}

private struct CombinedRiskCellView: View {
    
    @FetchRequest private var tweakCells: FetchedResults<TweakCell>
    
    init() {
        let latestTweakCellRequest = NSFetchRequest<TweakCell>()
        latestTweakCellRequest.entity = TweakCell.entity()
        latestTweakCellRequest.fetchLimit = 1
        latestTweakCellRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TweakCell.collected, ascending: false)]
        _tweakCells = FetchRequest(fetchRequest: latestTweakCellRequest)
    }
    
    var body: some View {
        ScrollView {
            CalculatedRiskView()
            
            if !tweakCells.isEmpty {
                CellInformationCard(cell: tweakCells[0])
            }
            
            OpenSysdiagnoseSettings()
        }
    }
    
}

private struct CalculatedRiskView: View {
    
    @State private var risk: RiskLevel = .Unknown
    @State private var timer: Timer? = nil
    
    var body: some View {
        return RiskIndicatorCard(risk: risk)
            .onAppear() {
                // Update the risk indicator asynchronously to reduce the Core Data load
                timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    DispatchQueue.global(qos: .utility).async {
                        let risk = PersistenceController.basedOnEnvironment().determineDataRiskStatus()
                        DispatchQueue.main.async {
                            self.risk = risk
                        }
                    }
                }
            }
            .onDisappear() {
                timer?.invalidate()
            }
    }
    
}

struct SummaryView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
