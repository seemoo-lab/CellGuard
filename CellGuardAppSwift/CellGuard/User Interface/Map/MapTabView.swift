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
import NavigationBackport

struct MapTabView: View {

    @Environment(\.managedObjectContext)
    private var managedContext: NSManagedObjectContext

    @ObservedObject private var locationManager = LocationDataManagerPublished.shared

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CellALS.imported, ascending: false)],
        predicate: NSPredicate(format: "location != nil AND observedCells != nil")
    )
    private var alsCells: FetchedResults<CellALS>

    @State private var navigationActive = false
    @State private var navigationTarget: NSManagedObjectID?
    @State private var infoSheetShown = false

    var body: some View {
        NavigationView {
            ZStack {
                // Cell Details
                // https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-programmatic-navigation-in-swiftui
                NavigationLink(isActive: $navigationActive) {
                    if let target = navigationTarget,
                       let cell = managedContext.object(with: target) as? CellALS {
                        CellDetailsView(alsCell: cell)
                    } else {
                        Text("Cell not found")
                    }
                } label: {
                    EmptyView()
                }
                .frame(width: 0, height: 0)
                .hidden()

                // Map
                MultiCellMap(locationInfo: locationManager, alsCells: alsCells) { cellID in
                    navigationTarget = cellID
                    navigationActive = true
                }
                .ignoresSafeArea()

                // Info Button
                HStack {
                    Spacer()
                    MapInfoButton {
                        infoSheetShown = true
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                // It's quite important to set the right button style, otherwise the whole map is the tap area
                // See: https://stackoverflow.com/a/70400079
                .buttonStyle(.borderless)

            }
            .sheet(isPresented: $infoSheetShown) {
                MapInfoSheet()
            }
        }
    }
}

private struct MapInfoButton: View {

    @Environment(\.colorScheme) var colorScheme

    private let onTap: () -> Void

    init(onTap: @escaping () -> Void) {
        self.onTap = onTap
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            Image(systemName: "info.circle")
        }
        .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
        .roundedThinMaterialBackground(color: colorScheme)
        .padding(EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6))
    }

}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
