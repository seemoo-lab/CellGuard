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
    
    let alsCells: FetchedResults<ALSCell>
    let tweakCells: FetchedResults<TweakCell>
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        
        mapView.showsUserLocation = true
        
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        
        let region = MKCoordinateRegion(
            center: middleLocation(),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        mapView.setRegion(region, animated: false)
        
        CommonCellMap.registerAnnotations(mapView)
        
        mapView.delegate = context.coordinator
        
        return mapView
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
        CommonCellMap.updateCellAnnotations(data: alsCells, uiView: uiView)
        CommonCellMap.updateLocationAnnotations(data: tweakCells, uiView: uiView)
    }
    
    func makeCoordinator() -> CellMapDelegate {
        return CellMapDelegate(onTap: { _ in })
    }
    
    static func hasAnyLocation(_ alsCells: FetchedResults<ALSCell>, _ tweakCells: FetchedResults<TweakCell>) -> Bool {
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
