//
//  SummaryView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.01.23.
//

import CoreData
import SwiftUI
import NavigationBackport

struct SummaryTabView: View {

    @State private var path = NBNavigationPath()
    @State private var cellFilterSettings = CellListFilterSettings()

    init() {
    }

    var body: some View {
        NBNavigationStack(path: $path) {
            CombinedRiskCellView()
            .navigationTitle("Summary")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        NBNavigationLink(value: SummaryNavigationPath.cellList) {
                            Label("Cells", systemImage: "wave.3.left")
                        }
                        #if STATS_VIEW
                        // Disable stats for the beta test as it is not finished.
                        NBNavigationLink(value: SummaryNavigationPath.dataSummary) {
                            Label("Stats", systemImage: "chart.bar.xaxis")
                        }
                        #endif
                        #if DEBUG
                        NBNavigationLink(value: SummaryNavigationPath.cellLaboratory) {
                            Label("Cell Laboratory", systemImage: "leaf")
                        }
                        NBNavigationLink(value: SummaryNavigationPath.operatorLookup) {
                            Label("Operators", systemImage: "globe")
                        }
                        #endif
                        Link(destination: CellGuardURLs.baseUrl) {
                            Label("Help", systemImage: "book")
                        }
                        NBNavigationLink(value: SummaryNavigationPath.settings) {
                            Label("Settings", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .imageScale(.large)
                    }
                }
            }
            .nbNavigationDestination(for: SummaryNavigationPath.self, destination: SummaryNavigationPath.navigate)
            .nbNavigationDestination(for: NavObjectId<CellTweak>.self) { id in
                id.ensure { CellDetailsView(tweakCell: $0) }
            }
            .nbNavigationDestination(for: NavObjectId<CellALS>.self) { id in
                id.ensure { CellDetailsView(alsCell: $0) }
            }
            .nbNavigationDestination(for: CellDetailsNavigation.self) { nav in
                nav.cell.ensure { cell in
                    CellDetailsView(tweakCell: cell, predicate: nav.predicate)
                }
            }
            .nbNavigationDestination(for: RiskLevel.self) { riskLevel in
                RiskInfoView(risk: riskLevel)
            }
            .nbNavigationDestination(for: NavObjectId<PacketARI>.self) { id in
                id.ensure { PacketARIDetailsView(packet: $0) }
            }
            .nbNavigationDestination(for: NavObjectId<PacketQMI>.self) { id in
                id.ensure { PacketQMIDetailsView(packet: $0) }
            }
            .nbNavigationDestination(for: NavObjectId<VerificationState>.self) { id in
                id.ensure { VerificationStateView(verificationState: $0) }
            }
            .nbNavigationDestination(for: [NetworkOperator].self) { ops in
                if ops.count == 1, let op = ops.first {
                    OperatorDetailsView(netOperator: op)
                } else {
                    OperatorDetailsListView(netOperators: ops)
                }
            }
            .nbNavigationDestination(for: CountryDetailsNavigation<NetworkCountry>.self) { data in
                CountryDetailsView(country: data.country, secondary: data.secondary)
            }
            .nbNavigationDestination(for: CountryDetailsNavigation<NetworkOperator>.self) { data in
                CountryDetailsView(country: data.country, secondary: data.secondary)
            }
            .nbNavigationDestination(for: CellDetailsTowerNavigation.self) { data in
                CellDetailsTowerView(nav: data)
            }
            .nbNavigationDestination(for: TweakCellMeasurementListNav.self) { data in
                TweakCellMeasurementList(nav: data)
            }
        }
        .background(Color.gray)
        .environmentObject(cellFilterSettings)
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

#if JAILBREAK
            // jailbreak mode: show update check info
            UpdateCheckInfoCard()
#endif

            if let tweakCell = tweakCellsSlot1.first {
                CellInformationCard(cell: tweakCell, dualSim: !tweakCellsSlot2.isEmpty)
            }
            if let tweakCell = tweakCellsSlot2.first {
                CellInformationCard(cell: tweakCell, dualSim: !tweakCellsSlot1.isEmpty)
            }

            // none mode: show warning, might not be intended
            NoneModeCard()

            // manual mode: show debug profile import instructions
            DebugProfileCard()

            // manual mode: show sys diagnose taking instructions
            SysdiagInstructionsCard()

            // manual mode: show link to opening sysdiag settings
            SysdiagOpenSettingsCard()

#if JAILBREAK
            // jailbreak mode: show tweak installation info
            TweakInstallInfoCard()
#endif
        }
    }

}

private struct CalculatedRiskView: View {

    @State private var risk: RiskLevel = .unknown
    @State private var timer: Timer?

    var body: some View {
        return RiskIndicatorCard(risk: risk)
            .onAppear {
                func computeRiskStatus() {
                    DispatchQueue.global(qos: .utility).async {
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
            .onDisappear {
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
