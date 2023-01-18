//
//  SummaryView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.01.23.
//

import SwiftUI

struct SummaryView: View {
    
    let showSettings: () -> ()
    
    @EnvironmentObject var locationManager: LocationDataManager
    @EnvironmentObject var networkAuthorization: LocalNetworkAuthorization
    @EnvironmentObject var notificationManager: CGNotificationManager
    
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TweakCell.collected, ascending: false)])
    private var tweakCells: FetchedResults<TweakCell>
    
    var body: some View {
        NavigationView {
            
            // TODO: Detection status
            // TODO: Permission status
            // TODO: Currenctly connected to ...
            
            ScrollView {
                RiskIndicatorCard(risk: determineRisk(), onTap: { risk in
                    // TODO: Do something
                    if risk == .Medium(cause: .Permissions) {
                        showSettings()
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
                        // person.crop.circle
                        // gear
                        // ellipsis.circle
                        Label("Settings", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .background(Color.gray)
    }
    
    func determineRisk() -> RiskLevel {
        if locationManager.authorizationStatus != .authorizedAlways ||
            !(networkAuthorization.lastResult ?? true) ||
            notificationManager.authorizationStatus != .authorized {
            return .Medium(cause: .Permissions)
        }
        
        return .Unknown
    }
}

struct SummaryView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryView {
            // doing nothing
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(LocationDataManager(extact: true))
        .environmentObject(LocalNetworkAuthorization(checkNow: true))
        .environmentObject(CGNotificationManager.shared)
    }
}
