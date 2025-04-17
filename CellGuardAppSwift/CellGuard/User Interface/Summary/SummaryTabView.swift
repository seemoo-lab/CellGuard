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
    #if STATS_VIEW
    @State private var showingStats = false
    #endif
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack {
                NavigationLink(isActive: $showingCellList) {
                    CellListView()
                } label: {
                    EmptyView()
                }
                #if STATS_VIEW
                NavigationLink(isActive: $showingStats) {
                    DataSummaryView()
                } label: {
                    EmptyView()
                }
                #endif

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
                            Label("Cells", systemImage: "wave.3.left")
                        }
                        #if STATS_VIEW
                        // Disable stats for the beta test as it is not finished.
                        Button {
                            showingStats = true
                        } label: {
                            Label("Stats", systemImage: "chart.bar.xaxis")
                        }
                        #endif
                        Link(destination: CellGuardURLs.baseUrl) {
                            Label("Help", systemImage: "book")
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
    @FetchRequest private var tweakCellsSlot1: FetchedResults<CellTweak>
    @FetchRequest private var tweakCellsSlot2: FetchedResults<CellTweak>
    
    init() {
        let latestTweakCellRequest = NSFetchRequest<CellTweak>()
        latestTweakCellRequest.entity = CellTweak.entity()
        latestTweakCellRequest.fetchLimit = 1
        latestTweakCellRequest.predicate = NSPredicate(format: "simSlotID = 1")
        latestTweakCellRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CellTweak.collected, ascending: false)]
        
        let dualSimCellRequest = NSFetchRequest<CellTweak>()
        dualSimCellRequest.entity = CellTweak.entity()
        dualSimCellRequest.fetchLimit = 1
        dualSimCellRequest.predicate = NSPredicate(format: "simSlotID = 2")
        dualSimCellRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CellTweak.collected, ascending: false)]
        
        _tweakCellsSlot1 = FetchRequest(fetchRequest: latestTweakCellRequest)
        _tweakCellsSlot2 = FetchRequest(fetchRequest: dualSimCellRequest)
    }
    
    var body: some View {
        ScrollView {
            CalculatedRiskView()
            
            if let tweakCell = tweakCellsSlot1.first {
                NavigationLink {
                    CellDetailsView(tweakCell: tweakCell)
                } label: {
                    CellInformationCard(cell: tweakCell, dualSim: !tweakCellsSlot2.isEmpty)
                }
                .buttonStyle(.plain)
            }
            if let tweakCell = tweakCellsSlot2.first {
                NavigationLink {
                    CellDetailsView(tweakCell: tweakCell)
                } label: {
                    CellInformationCard(cell: tweakCell, dualSim: !tweakCellsSlot1.isEmpty)
                }
                .buttonStyle(.plain)
            }
            
            // none mode: show warning, might not be intended
            NoneModeCard()
            
            // manual mode: show debug profile import instructions
            DebugProfileCard()
            
            // manual mode: show sys diagnose taking instructions
            SysdiagInstructionsCard()
            
            // manual mode: show link to opening sysdiag settings
            SysdiagOpenSettingsCard()
            
            // jailbreak mode: show tweak installation info
#if JAILBREAK
            TweakInstallInfoCard()
#endif
        }
    }
    
}

private struct CalculatedRiskView: View {
    
    @State private var risk: RiskLevel = .Unknown
    @State private var timer: Timer? = nil
    
    var body: some View {
        return RiskIndicatorCard(risk: risk)
            .onAppear() {
                func computeRiskStatus() {
                    DispatchQueue.global(qos: .utility).async {
                        // TODO: Can we reduce the CPU load of this check?
                        let risk = PersistenceController.basedOnEnvironment().determineDataRiskStatus()
                        DispatchQueue.main.async {
                            self.risk = risk
                        }
                    }
                }
                
                // Update the risk indicator asynchronously to reduce the Core Data load
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    // Skip the update of the risk status if the app is in the background
                    if UIApplication.shared.applicationState == .background {
                        return
                    }
                    
                    computeRiskStatus()
                }
                
                // Instantly compute the new risk status
                computeRiskStatus()
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
