//
//  MapView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.01.23.
//

import SwiftUI
import UIKit
import MapKit
import CoreData

struct MapTabView: View {
    
    @Environment(\.managedObjectContext)
    private var managedContext: NSManagedObjectContext
    
    @EnvironmentObject
    private var locationManager: LocationDataManager
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ALSCell.imported, ascending: false)],
        predicate: NSPredicate(format: "location != nil")
    )
    private var alsCells: FetchedResults<ALSCell>

    @State private var navigationActive = false
    @State private var navigationTarget: NSManagedObjectID? = nil
    
    
    var body: some View {
        NavigationView {
            VStack {
                // https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-programmatic-navigation-in-swiftui
                // TODO: I guess this isn't liked? Better use ZStack?
                NavigationLink(isActive: $navigationActive) {
                    if let target = navigationTarget,
                       let cell = managedContext.object(with: target) as? ALSCell {
                        CellDetailsView(cell: cell)
                    } else {
                        Text("Cell not found")
                    }
                } label: {
                    EmptyView()
                }
                MultiCellMap(alsCells: alsCells) { cellID in
                    navigationTarget = cellID
                    navigationActive = true
                }
                .ignoresSafeArea()
            }
        }
    }
}


struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(LocationDataManager.shared)
    }
}
