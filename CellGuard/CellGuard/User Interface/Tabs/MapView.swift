//
//  MapView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.01.23.
//

import SwiftUI
import UIKit
import MapKit

struct MapView: View {
    
    // let onTap: (ALSCell) -> ()
    
    @EnvironmentObject
    private var locationManager: LocationDataManager
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ALSCell.imported, ascending: true)],
        predicate: NSPredicate(format: "location != nil")
    )
    private var alsCells: FetchedResults<ALSCell>
    
    @State
    private var userTrackingMode = MapUserTrackingMode.follow
    
    var body: some View {
        let location = locationManager.lastLocation ?? CLLocation(latitude: 49.8726737, longitude: 8.6516291)
        NavigationView {
            Map(
                coordinateRegion: .constant(
                    MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))),
                showsUserLocation: true,
                userTrackingMode: $userTrackingMode,
                annotationItems: alsCells,
                annotationContent: { alsCell in
                    CellTowerIcon.asAnnotation(cell: alsCell) {
                        CellDetailsView(cell: alsCell)
                    }
                }
            ).ignoresSafeArea()
        }
    }
}

struct CellTowerIcon: View {
    let cell: Cell
    
    private init(cell: Cell) {
        self.cell = cell
    }
    
    var body: some View {
        Image(systemName: "antenna.radiowaves.left.and.right")
            .foregroundColor(color())
            .padding(EdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
            .font(.title2)
            .background(Circle()
                .foregroundColor(.white)
                .shadow(radius: 2)
            )
    }

    private func color() -> Color {
        // TODO: Add more colors
        switch (cell.network % 5) {
        case 0:
            return .green
        case 1:
            return .pink
        case 2:
            return .red
        case 3:
            return .blue
        case 4:
            return .orange
        default:
            return .gray
        }
    }
    
    public static func asAnnotation(cell: Cell) -> MapAnnotation<AnyView> {
        return MapAnnotation(coordinate: CLLocationCoordinate2D(
            latitude: cell.location?.latitude ?? 0,
            longitude: cell.location?.longitude ?? 0
        )) {
            AnyView(CellTowerIcon(cell: cell))
        }
    }
    
    public static func asAnnotation<Destination: View>(cell: Cell, destination: () -> Destination)
        -> MapAnnotation<NavigationLink<CellTowerIcon, Destination>> {
        return MapAnnotation(coordinate: CLLocationCoordinate2D(
            latitude: cell.location?.latitude ?? 0,
            longitude: cell.location?.longitude ?? 0
        )) {
            NavigationLink {
                destination()
            } label: {
                CellTowerIcon(cell: cell)
            }
        }
    }
    
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(LocationDataManager(extact: true))
    }
}
