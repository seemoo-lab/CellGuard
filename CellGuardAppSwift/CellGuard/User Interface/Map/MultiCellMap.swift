//
//  CellMap.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.01.23.
//

import CoreData
import CoreLocation
import SwiftUI
import UIKit
import MapKit

// https://www.hackingwithswift.com/quick-start/swiftui/how-to-wrap-a-custom-uiview-for-swiftui
// https://developer.apple.com/documentation/coredata/nsfetchedresultscontroller
// https://medium.com/@nimjea/mapkit-in-swiftui-c0cc2b07c28a
// https://developer.apple.com/documentation/mapkit/mapkit_annotations/annotating_a_map_with_custom_data


struct MultiCellMap: UIViewRepresentable {
    
    let alsCells: any BidirectionalCollection<CellALS>
    let onTap: (NSManagedObjectID) -> Void
    
    @ObservedObject private var locationManager = LocationDataManager.shared
    
    init(alsCells: any BidirectionalCollection<CellALS>, onTap: @escaping (NSManagedObjectID) -> Void) {
        self.alsCells = alsCells
        self.onTap = onTap
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        // Limit the maximum zoom range of the camera to 200km, otherwise there are performance issues with too many annotations displayed
        // mapView.cameraZoomRange = MKMapView.CameraZoomRange(maxCenterCoordinateDistance: 500_000)
        // We don't require this limit if we only show cells the iPhone connected to (which also makes more sense for users).
        
        // TODO: Extract lastLocation into sub struct of the LocationDataManger
        let location = locationManager.lastLocation ?? CLLocation(latitude: 49.8726737, longitude: 8.6516291)
        let region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        mapView.setRegion(region, animated: false)
        
        CommonCellMap.registerAnnotations(mapView)
        
        mapView.delegate = context.coordinator
        
        // TODO: Add user tracking button
        // See: https://developer.apple.com/documentation/mapkit/mkusertrackingbutton
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Don't update map annotations if the app is in the background
        if UIApplication.shared.applicationState == .background {
            return
        }
        
        _ = CommonCellMap.updateCellAnnotations(data: alsCells, uiView: uiView)
    }
    
    func makeCoordinator() -> CellMapDelegate {
        return CellMapDelegate(onTap: onTap, clustering: true)
    }
    
}

/* struct CellMap_Previews: PreviewProvider {
    static var previews: some View {
        CellMap()
    }
}
*/
