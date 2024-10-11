//
//  SingleCellMap.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.01.23.
//

import CoreData
import MapKit
import SwiftUI
import UIKit

struct SingleCellMap: UIViewRepresentable {
    
    let alsCells: any BidirectionalCollection<CellALS>
    let tweakCells: any BidirectionalCollection<CellTweak>
    
    /// Finds an the first location based on the passed cells and user locations
    private func findApproximateRegion() -> CLLocationCoordinate2D {
        if let alsCell = alsCells.first, let location = alsCell.location {
            return CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        }
        
        for tweakCell in tweakCells {
            if let location = tweakCell.location {
                return CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
            }
        }
        
        // Default location
        return CLLocationCoordinate2D(
            latitude: 49.8726737,
            longitude: 8.6516291
        )
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        
        mapView.showsUserLocation = true
        
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        
        // Limit the maximum zoom range of the camera to 50km as all locations should be within this range
        mapView.cameraZoomRange = MKMapView.CameraZoomRange(maxCenterCoordinateDistance: 50_000)
        mapView.setRegion(MKCoordinateRegion(center: findApproximateRegion(), latitudinalMeters: 1000, longitudinalMeters: 1000), animated: false)
        
        CommonCellMap.registerAnnotations(mapView)
        
        mapView.delegate = context.coordinator
        return mapView
    }
    
    /// Updates the view region based on the annotations
    private func updateViewRegion(_ mapView: MKMapView, animated: Bool) {
        let ownAnnotations = mapView.annotations.filter { $0 is DatabaseAnnotation || $0 is LocationClusterAnnotation || $0 is CellClusterAnnotation }
        mapView.showAnnotations(ownAnnotations, animated: animated)
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Don't update map annotations if the app is in the background
        if UIApplication.shared.applicationState == .background {
            return
        }
        
        _ = CommonCellMap.updateCellAnnotations(data: alsCells, uiView: uiView)
        _ = CommonCellMap.updateLocationAnnotations(data: tweakCells, uiView: uiView)
        
        // Update the shown map region if the cell annotation changes
        updateViewRegion(uiView, animated: false)
        
        // TODO: Enable reach overlay if performance has been improved
        // CommonCellMap.updateCellReachOverlay(data: alsCells, uiView: uiView)        
    }
    
    func makeCoordinator() -> CellMapDelegate {
        return CellMapDelegate()
    }
    
    static func hasAnyLocation(_ alsCells: any BidirectionalCollection<CellALS>, _ tweakCells: any BidirectionalCollection<CellTweak>) -> Bool {
        if alsCells.first(where: { $0.location != nil}) != nil {
            return true
        }
        
        if tweakCells.first(where: { $0.location != nil}) != nil {
            return true
        }
        
        return false
    }
}


/* struct SingleCellMap_Previews: PreviewProvider {
    static var previews: some View {
        SingleCellMap()
    }
} */
