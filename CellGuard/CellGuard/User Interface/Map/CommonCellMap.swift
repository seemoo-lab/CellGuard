//
//  CellMap.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.01.23.
//

import CoreData
import Foundation
import MapKit
import SwiftUI

struct CommonCellMap {
    
    private init() {
        // Prevent anyone from initializing this struct
    }
    
    static func registerAnnotations(_ mapView: MKMapView) {
        // Idea to fix the red pin problem: Put a prefix before each reuse identifier,
        // but that doesn't seem to have an effect on the issue.
        
        // Single point annotations
        mapView.register(
            CellAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: CellAnnotationView.ReuseID)
        mapView.register(
            LocationAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: LocationAnnotationView.ReuseID)
        
        // Cluster annotations
        mapView.register(
            LocationAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: LocationAnnotationView.ClusterReuseID)
        mapView.register(
            CellClusterAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: CellClusterAnnotationView.ReuseID)
    }
    
    private static func updateAnnotations<D: NSManagedObject, A: DatabaseAnnotation>(
        data: any BidirectionalCollection<D>, uiView: MKMapView, create: (D) -> A?
    ) -> (Int, Int) {
        // Pick all annotations of the given type
        let presentAnnotations = uiView.annotations
            .map { $0 as? A }
            .compactMap { $0 }
        // Get the coreDataID from all annotations
        let oldIDSet = Set(presentAnnotations.map { $0.coreDataID })
        
        // Map the new data from the database into a dictionary of ID <-> Object
        let newIDMap = Dictionary(
            uniqueKeysWithValues: data
                .map{ $0 as D }
                .map { ($0.objectID, $0) }
        )
        
        // Remove annotation which are on the map but are not part of the query result
        let removeAnnotations = presentAnnotations
            .filter { !newIDMap.keys.contains($0.coreDataID) }
        uiView.removeAnnotations(removeAnnotations)
        
        // Add the new annotations which aren't displayed on the map but are part of the result
        let addAnnotations = newIDMap
            .filter { !oldIDSet.contains($0.key) }
            .map { create($0.value) }
            .compactMap { $0 }
        uiView.addAnnotations(addAnnotations)
        
        // Return the number of cell which are added and the number of the ones which are removed
        return (addAnnotations.count, removeAnnotations.count)
    }
    
    static func updateCellAnnotations(data: any BidirectionalCollection<CellALS>, uiView: MKMapView) -> (Int, Int) {
        updateAnnotations(data: data, uiView: uiView) { cell in
            CellAnnotation(cell: cell)
        }
    }
    
    static func updateLocationAnnotations(data: any BidirectionalCollection<CellTweak>, uiView: MKMapView) -> (Int, Int) {
        let locations = Array(Set(data.compactMap { $0.location }))
        
        return updateAnnotations(data: locations, uiView: uiView) { location in
            LocationAnnotation(location: location)
        }
    }
    
    private static func updateOverlay<D: NSManagedObject, A: CellReachOverlay>(data: any BidirectionalCollection<D>, uiView: MKMapView, create: (D) -> A?) {
        // Pick all overlays of the given type
        let presentOverlays = uiView.overlays
            .map { $0 as? A }
            .compactMap { $0 }
        // Get the coreDataID from all annotations
        let oldIDSet = Set(presentOverlays.map { $0.coreDataID })
        
        // Map the new data from the database into a dictionary of ID <-> Object
        let newIDMap = Dictionary(
            uniqueKeysWithValues: data
                .map{ $0 as D }
                .map { ($0.objectID, $0) }
        )
        
        // Remove overlays which are on the map but are not part of the query result
        let removeOverlays = presentOverlays
            .filter { !newIDMap.keys.contains($0.coreDataID) }
        uiView.removeOverlays(removeOverlays)
        
        // Add the new overlays which aren't displayed on the map but are part of the result
        let addOverlays = newIDMap
            .filter { !oldIDSet.contains($0.key) }
            .map { create($0.value) }
            .compactMap { $0 }
        uiView.addOverlays(addOverlays)
    }
    
    static func updateCellReachOverlay(data: FetchedResults<CellALS>, uiView: MKMapView) {
        let locations = Array(Set(data.compactMap { $0.location }))
        
        updateOverlay(data: locations, uiView: uiView) { location in
            CellReachOverlay(location: location)
        }
    }
    
}
