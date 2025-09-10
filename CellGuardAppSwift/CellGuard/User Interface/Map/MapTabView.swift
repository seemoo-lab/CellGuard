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

    @State private var path = NBNavigationPath()
    @State private var infoSheetShown = false

    var body: some View {
        NBNavigationStack {
            MapWithButton {
                infoSheetShown = true
            }
            .sheet(isPresented: $infoSheetShown) {
                MapInfoSheet()
            }
            .cgNavigationDestinations(.cells)
            .cgNavigationDestinations(.operators)
            .cgNavigationDestinations(.packets)
        }
    }
}

private struct MapWithButton: View {
    var showInfoSheet: () -> Void

    var body: some View {
        if #available(iOS 26, *) {
            MapWithButtonToolbar(showInfoSheet: showInfoSheet)
        } else {
            MapWithButtonBottom(showInfoSheet: showInfoSheet)
        }
    }

}

private struct MapWithButtonToolbar: View {
    var showInfoSheet: () -> Void

    var body: some View {
        ConnectedCellMap()
            .toolbar {
                ToolbarItem {
                    Button(action: showInfoSheet) {
                        Image(systemName: "info")
                    }
                }
            }
    }
}

private struct MapWithButtonBottom: View {
    var showInfoSheet: () -> Void

    var body: some View {
        // Map
        ConnectedCellMap()

        // Info Button
        HStack {
            Spacer()
            OpaqueMapInfoButton(onTap: showInfoSheet)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        // It's quite important to set the right button style, otherwise the whole map is the tap area
        // See: https://stackoverflow.com/a/70400079
        .buttonStyle(.borderless)
    }
}

private struct ConnectedCellMap: View {

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CellALS.imported, ascending: false)],
        predicate: NSPredicate(format: "location != nil AND observedCells != nil")
    )
    private var alsCells: FetchedResults<CellALS>

    @EnvironmentObject var navigator: PathNavigator
    @ObservedObject private var locationManager = LocationDataManagerPublished.shared

    var body: some View {
        MultiCellMap(locationInfo: locationManager, alsCells: alsCells) { cellID in
            print(cellID)
            navigator.push(NavObjectId<CellALS>(id: cellID))
        }
        .ignoresSafeArea()
    }
}

private struct OpaqueMapInfoButton: View {

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
