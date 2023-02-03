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
    let showProgress: () -> Void
    let showListTab: () -> Void
    
    @EnvironmentObject var locationManager: LocationDataManager
    @EnvironmentObject var networkAuthorization: LocalNetworkAuthorization
    @EnvironmentObject var notificationManager: CGNotificationManager
    
    @FetchRequest private var tweakCells: FetchedResults<TweakCell>
    @FetchRequest private var failedCells: FetchedResults<TweakCell>
    @FetchRequest private var unknownCells: FetchedResults<TweakCell>
    
    init(showSettings: @escaping () -> Void, showProgress: @escaping () -> Void, showListTab: @escaping () -> Void) {
        self.showSettings = showSettings
        self.showProgress = showProgress
        self.showListTab = showListTab
        
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
            ScrollView {
                RiskIndicatorCard(risk: determineRisk(), onTap: { risk in
                    switch (risk) {
                    case .Low:
                        showListTab()
                    case let .Medium(cause):
                        if cause == .Permissions {
                            showSettings()
                        } else if cause == .Tweak {
                            // TODO: Show explain sheet
                        }
                    case .High(_):
                        showListTab()
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
                    Button {
                        self.showSettings()
                    } label: {
                        Label("Settings", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .background(Color.gray)
    }
    
    func determineRisk() -> RiskLevel {
        if failedCells.count > 0 {
            return .High(count: failedCells.count)
        }
        
        // TODO: A condition is false at the start of the app, figure out which
        if (locationManager.authorizationStatus ?? .authorizedAlways) != .authorizedAlways ||
            !(networkAuthorization.lastResult ?? true) ||
            (notificationManager.authorizationStatus ?? .authorized) != .authorized {
            return .Medium(cause: .Permissions)
        }
        
        if unknownCells.count > 0 {
            return .Unknown
        } else {
            return .Low
        }
    }
}

struct SummaryView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryTabView {
            // doing nothing
        } showProgress: {
            // doing nothing
        } showListTab: {
            // doing nothing
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(LocationDataManager.shared)
        .environmentObject(LocalNetworkAuthorization(checkNow: true))
        .environmentObject(CGNotificationManager.shared)
    }
}
