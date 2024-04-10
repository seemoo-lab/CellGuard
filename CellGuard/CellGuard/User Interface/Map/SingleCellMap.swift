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
    
    let alsCells: any BidirectionalCollection<ALSCell>
    let tweakCells: any BidirectionalCollection<TweakCell>
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        
        mapView.showsUserLocation = true
        
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        
        // Limit the maximum zoom range of the camera to 50km as all locations should be within this range
        mapView.cameraZoomRange = MKMapView.CameraZoomRange(maxCenterCoordinateDistance: 50_000)
        
        mapView.setRegion(middleRegion(), animated: false)
        
        CommonCellMap.registerAnnotations(mapView)
        
        mapView.delegate = context.coordinator
        
        return mapView
    }
    
    private func middleRegion() -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: middleLocation(),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    }
    
    private func middleLocation() -> CLLocationCoordinate2D {
        if let alsCell = alsCells.first,
           let location = alsCell.location {
            return CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        }
        
        let firstTweakCellLocation = tweakCells.compactMap { $0.location }.first
        if let location = firstTweakCellLocation {
            return CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        }
        
        return CLLocationCoordinate2D(
            latitude: 49.8726737,
            longitude: 8.6516291
        )
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        let (added, _) = CommonCellMap.updateCellAnnotations(data: alsCells, uiView: uiView)
        _ = CommonCellMap.updateLocationAnnotations(data: tweakCells, uiView: uiView)
        
        // Update the shown map region if the cell annotation changes
        if added > 0 {
            uiView.setRegion(middleRegion(), animated: true)
        }
        
        // TODO: Enable reach overlay if performance has been improved
        // CommonCellMap.updateCellReachOverlay(data: alsCells, uiView: uiView)        
    }
    
    func makeCoordinator() -> CellMapDelegate {
        return CellMapDelegate()
    }
    
    static func hasAnyLocation(_ alsCells: any BidirectionalCollection<ALSCell>, _ tweakCells: any BidirectionalCollection<TweakCell>) -> Bool {
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
