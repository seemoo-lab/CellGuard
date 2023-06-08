//
//  SummaryView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.01.23.
//

import CoreData
import SwiftUI

struct SummaryTabView: View {
    
    let showSettings: () -> Void
    let showExport: () -> Void
    let showProgress: () -> Void
    let showTweakInfo: () -> Void
    
    @State var isShowingConnectedCells = false
    
    @EnvironmentObject var locationManager: LocationDataManager
    @EnvironmentObject var networkAuthorization: LocalNetworkAuthorization
    @EnvironmentObject var notificationManager: CGNotificationManager
    
    @FetchRequest private var tweakCells: FetchedResults<TweakCell>
    @FetchRequest private var failedCells: FetchedResults<TweakCell>
    @FetchRequest private var unknownCells: FetchedResults<TweakCell>
    
    init(showSettings: @escaping () -> Void, showExport: @escaping () -> Void, showProgress: @escaping () -> Void, showTweakInfo: @escaping () -> Void) {
        self.showSettings = showSettings
        self.showExport = showExport
        self.showProgress = showProgress
        self.showTweakInfo = showTweakInfo
        
        let latestTweakCellRequest = NSFetchRequest<TweakCell>()
        latestTweakCellRequest.entity = TweakCell.entity()
        latestTweakCellRequest.fetchLimit = 1
        latestTweakCellRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TweakCell.collected, ascending: false)]
        
        _tweakCells = FetchRequest(fetchRequest: latestTweakCellRequest)
        
        let calendar = Calendar.current
        let ftDaysAgo = calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: Date()))!
        
        let ftPredicate = NSPredicate(format: "collected >= %@", ftDaysAgo as NSDate)
        let failedPredicate = NSPredicate(format: "status == %@", CellStatus.failed.rawValue)
        let unknownPredicate = NSPredicate(format: "status == %@", CellStatus.imported.rawValue)
                
        _failedCells = FetchRequest(
            sortDescriptors: [],
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [ftPredicate, failedPredicate])
        )
        _unknownCells = FetchRequest(
            sortDescriptors: [],
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [ftPredicate, unknownPredicate])
        )
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // A hack for programmatic navigation
                // https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-programmatic-navigation-in-swiftui
                NavigationLink(destination: CellsListView(), isActive: $isShowingConnectedCells) { EmptyView() }
                
                // The actual primary view
                ScrollView {
                    RiskIndicatorCard(risk: determineRisk(), onTap: { risk in
                        switch (risk) {
                        case .Low:
                            showConnectedCells()
                        case let .Medium(cause):
                            if cause == .Permissions {
                                showSettings()
                            } else if cause == .Tweak {
                                showTweakInfo()
                            }
                        case .High(_):
                            showConnectedCells()
                        case .Unknown:
                            showProgress()
                        }
                    })
                    if !tweakCells.isEmpty {
                        CellInformationCard(cell: tweakCells[0])
                    }
                }
                .navigationTitle("Summary")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(action: self.showConnectedCells) {
                                Label("Connected Cells", systemImage: "list.bullet")
                            }
                            Button(action: self.showExport) {
                                Label("Export Data", systemImage: "square.and.arrow.up")
                            }
                            Button(action: self.showSettings) {
                                Label("Settings", systemImage: "gear")
                            }
                        } label: {
                            Label("Settings", systemImage: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .background(Color.gray)
    }
    
    func determineRisk() -> RiskLevel {
        // We keep the unknown status until all cells are verified because we're sending notifications during verification
        if unknownCells.count > 0 {
            return .Unknown
        }
        
        if failedCells.count > 0 {
            return .High(count: failedCells.count)
        }
        
        // We've received no cells for 30 minutes from the tweak, so we warn the user
        let ftMinutesAgo = Date() - 30 * 60
        if tweakCells.isEmpty || tweakCells.first!.collected! < ftMinutesAgo {
            return .Medium(cause: .Tweak)
        }
        
        // TODO: A condition is false at the start of the app, figure out which
        if (locationManager.authorizationStatus ?? .authorizedAlways) != .authorizedAlways ||
            !(networkAuthorization.lastResult ?? true) ||
            (notificationManager.authorizationStatus ?? .authorized) != .authorized {
            return .Medium(cause: .Permissions)
        }
        
        return .Low
    }
    
    func showConnectedCells() {
        isShowingConnectedCells = true
    }
}

struct SummaryView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryTabView {
            // doing nothing
        } showExport: {
            // doing nothing
        } showProgress: {
            // doing nothing
        } showTweakInfo: {
            // doing nothing
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(LocationDataManager.shared)
        .environmentObject(LocalNetworkAuthorization(checkNow: true))
        .environmentObject(CGNotificationManager.shared)
    }
}
