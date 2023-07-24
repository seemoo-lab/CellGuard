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
            CalculatedRiskView(latestTweakCell: tweakCells.first)
            
            if !tweakCells.isEmpty {
                CellInformationCard(cell: tweakCells[0])
            }
        }
    }
    
}

private struct CalculatedRiskView: View {
    
    @EnvironmentObject var locationManager: LocationDataManager
    @EnvironmentObject var networkAuthorization: LocalNetworkAuthorization
    @EnvironmentObject var notificationManager: CGNotificationManager
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TweakCell.collected, ascending: false)],
        predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
            Self.ftDaysPredicate(),
            NSPredicate(format: "status == %@", CellStatus.verified.rawValue),
            NSPredicate(format: "score < %@", CellVerifier.pointsUntrustedThreshold as NSNumber)
        ])
    )
    private var failedCells: FetchedResults<TweakCell>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TweakCell.collected, ascending: false)],
        predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
            Self.ftDaysPredicate(),
            NSPredicate(format: "status == %@", CellStatus.verified.rawValue),
            NSPredicate(format: "score < %@", CellVerifier.pointsSuspiciousThreshold as NSNumber)
        ])
    )
    private var suspiciousCells: FetchedResults<TweakCell>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TweakCell.collected, ascending: false)],
        predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
            Self.ftDaysPredicate(),
            NSPredicate(format: "status != %@", CellStatus.verified.rawValue),
        ])
    )
    private var unknownCells: FetchedResults<TweakCell>
    
    @FetchRequest private var qmiPackets: FetchedResults<QMIPacket>
    @FetchRequest private var ariPackets: FetchedResults<ARIPacket>
    
    let latestTweakCell: TweakCell?
    
    init(latestTweakCell: TweakCell?) {
        self.latestTweakCell = latestTweakCell
        
        let qmiPacketsRequest: NSFetchRequest<QMIPacket> = QMIPacket.fetchRequest()
        qmiPacketsRequest.sortDescriptors = [NSSortDescriptor(keyPath: \QMIPacket.collected, ascending: false)]
        qmiPacketsRequest.fetchLimit = 1
        self._qmiPackets = FetchRequest(fetchRequest: qmiPacketsRequest)
        
        let ariPacketsRequest: NSFetchRequest<ARIPacket> = ARIPacket.fetchRequest()
        ariPacketsRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ARIPacket.collected, ascending: false)]
        ariPacketsRequest.fetchLimit = 1
        self._ariPackets = FetchRequest(fetchRequest: ariPacketsRequest)
        
    }
    
    var body: some View {
        if failedCells.count > 0 {
            let cellCount = Dictionary(grouping: failedCells) { PersistenceController.queryCell(from: $0) }.count
            return RiskIndicatorCard(risk: .High(cellCount: cellCount))
        }
        
        if suspiciousCells.count > 0 {
            let cellCount = Dictionary(grouping: suspiciousCells) { PersistenceController.queryCell(from: $0) }.count
            return RiskIndicatorCard(risk: .Medium(cause: .Cells(cellCount: cellCount)))
        }
        
        // We keep the unknown status until all cells are verified (except the current cell which we are monitoring)
        if let unknownCell = unknownCells.first, unknownCell.status == CellStatus.processedLocation.rawValue {
            return RiskIndicatorCard(risk: .LowMonitor)
        } else if unknownCells.count > 0 {
            return RiskIndicatorCard(risk: .Unknown)
        }
        
        // We've received no cells for 30 minutes from the tweak, so we warn the user
        let ftMinutesAgo = Date() - 30 * 60
        guard let latestTweakCell = latestTweakCell else {
            return RiskIndicatorCard(risk: .Medium(cause: .TweakCells))
        }
        if latestTweakCell.collected ?? Date.distantPast < ftMinutesAgo {
            return RiskIndicatorCard(risk: .Medium(cause: .TweakCells))
        }
        
        
        let latestPacket = [qmiPackets.first as Packet?, ariPackets.first as Packet?]
            .compactMap { $0 }
            .sorted { return $0.collected ?? Date.distantPast < $1.collected ?? Date.distantPast }
            .last
        guard let latestPacket = latestPacket else {
            return RiskIndicatorCard(risk: .Medium(cause: .TweakPackets))
        }
        if latestPacket.collected ?? Date.distantPast < ftMinutesAgo {
            return RiskIndicatorCard(risk: .Medium(cause: .TweakPackets))
        }
        
        // TODO: A condition is false at the first start of the app, figure out which
        if (locationManager.authorizationStatus ?? .authorizedAlways) != .authorizedAlways ||
            !(networkAuthorization.lastResult ?? true) ||
            (notificationManager.authorizationStatus ?? .authorized) != .authorized {
            return RiskIndicatorCard(risk: .Medium(cause: .Permissions))
        }
        
        return RiskIndicatorCard(risk: .Low)
    }
    
    private static func ftDaysPredicate() -> NSPredicate {
        let calendar = Calendar.current
        let ftDaysAgo = calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: Date()))!
        return NSPredicate(format: "collected >= %@", ftDaysAgo as NSDate)
    }
    
}

struct SummaryView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(LocationDataManager.shared)
            .environmentObject(LocalNetworkAuthorization(checkNow: true))
            .environmentObject(CGNotificationManager.shared)
    }
}
