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
        sortDescriptors: [NSSortDescriptor(keyPath: \CellALS.imported, ascending: false)],
        predicate: NSPredicate(format: "location != nil AND observedCells != nil")
    )
    private var alsCells: FetchedResults<CellALS>
    
    @State private var navigationActive = false
    @State private var navigationTarget: NSManagedObjectID? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                // https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-programmatic-navigation-in-swiftui
                // TODO: I guess this isn't liked? Better use ZStack?
                NavigationLink(isActive: $navigationActive) {
                    if let target = navigationTarget,
                       let cell = managedContext.object(with: target) as? CellALS {
                        CellDetailsView(cell: cell)
                    } else {
                        Text("Cell not found")
                    }
                } label: {
                    EmptyView()
                }
                // TODO: Add button to an info page for the map explaining which cells are shown, how we get their position and what their color means.
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
