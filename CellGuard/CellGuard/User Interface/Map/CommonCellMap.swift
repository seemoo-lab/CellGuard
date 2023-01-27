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
        // Single point annotations
        mapView.register(
            CellAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        mapView.register(
            LocationAnnotation.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        
        // Cluster annotations
        mapView.register(
            CellClusterAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        mapView.register(
            LocationAnnotation.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
    }
    
    private static func updateAnnotations<D: NSManagedObject, A: DatabaseAnnotation>(data: any Sequence<D>, uiView: MKMapView, create: (D) -> A?) {
        // Pick all annotations of the given type
        let presentAnnotations = uiView.annotations
            .map { $0 as? A }
            .compactMap { $0 }
        // Get the coreDataID from all annotations
        let oldIDSet = Set(presentAnnotations.map { $0.coreDataID })
        
        // Map the new data from the database into a dictionary of ID <-> Object
        let newIDMap = Dictionary(
            uniqueKeysWithValues: data
                .map{ $0 as? D }
                .compactMap { $0 }
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
    }
    
    static func updateCellAnnotations(data: FetchedResults<ALSCell>, uiView: MKMapView) {
        updateAnnotations(data: data, uiView: uiView) { cell in
            CellAnnotation(cell: cell)
        }
    }
    
    static func updateLocationAnnotations(data: FetchedResults<TweakCell>, uiView: MKMapView) {
        let locations = Set(data.compactMap { $0.location })
        
        updateAnnotations(data: locations, uiView: uiView) { location in
            LocationAnnotation(location: location)
        }
    }
    
}