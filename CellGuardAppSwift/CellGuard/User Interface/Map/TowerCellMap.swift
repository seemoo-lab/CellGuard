//
//  CellTowerMap.swift
//  CellGuard
//
//  Created by Lukas Arnold on 20.10.24.
//

import CoreData
import SwiftUI
import UIKit
import MapKit

struct TowerCellMap: UIViewRepresentable {
    
    let alsCells: any BidirectionalCollection<CellALS>
    let dissect: (Int64) -> (Int64, Int64)
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        
        let location = LocationDataManager.shared.lastLocation ?? CLLocation(latitude: 49.8726737, longitude: 8.6516291)
        let region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        mapView.setRegion(region, animated: false)
        
        // Set initial position of map view based on annotations
        CommonCellMap.registerAnnotations(mapView)
        updateAnnotations(mapView)
        CommonCellMap.updateViewRegion(mapView, animated: false)
        
        mapView.delegate = context.coordinator
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Don't update map annotations if the app is in the background
        if UIApplication.shared.applicationState == .background {
            return
        }
        
        updateAnnotations(uiView)
    }
    
    private func updateAnnotations(_ uiView: MKMapView) {
        // Update cells annotation with custom title
        let (added, removed) = CommonCellMap.updateAnnotations(data: alsCells, uiView: uiView) { alsCell in
            let (_, section) = dissect(alsCell.cell)
            return CellAnnotation(cell: alsCell, title: "\(section)")
        }
        
        // Update center location (only if cells have been added or removed)
        if (added > 0 || removed > 0),
           let technology = alsCells.first?.technology,
           let technology = ALSTechnology(rawValue: technology)
        {
            let locations = alsCells.compactMap(\.location)
            
            // TODO: Factor in signal strengths (from QMI & ARI packets) to determine a more accurate tower position
            let avgLatitude = locations.map { $0.latitude }.reduce(0, +) / Double(locations.count)
            let avgLongitude = locations.map { $0.longitude }.reduce(0, +) / Double(locations.count)
            
            let towerAnnotation = TowerAnnotation(
                technology: technology,
                coordinate: CLLocationCoordinate2D(latitude: avgLatitude, longitude: avgLongitude),
                title: "Tower",
                subtitle: "Approximate Location"
            )
            
            uiView.annotations.filter { $0 is TowerAnnotation}.forEach { uiView.removeAnnotation($0) }
            uiView.addAnnotation(towerAnnotation)
        }
    }
    
    func makeCoordinator() -> CellMapDelegate {
        return CellMapDelegate(clustering: false)
    }
    
}
