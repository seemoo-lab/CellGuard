//
//  CellMapDelegate.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.01.23.
//

import CoreData
import Foundation
import MapKit

class CellMapDelegate: NSObject, MKMapViewDelegate {
    
    let onTap: ((NSManagedObjectID) -> Void)?
    
    init(onTap: ((NSManagedObjectID) -> Void)? = nil) {
        self.onTap = onTap
        super.init()
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if let annotation = view.annotation as? CellAnnotation {
            onTap?(annotation.coreDataID)
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is CellAnnotation {
            return CellAnnotationView(annotation: annotation, reuseIdentifier: CellAnnotationView.ReuseID, calloutAccessory: onTap != nil)
        } else if annotation is LocationAnnotation || annotation is LocationClusterAnnotation {
            return LocationAnnotationView(annotation: annotation, reuseIdentifier: LocationAnnotationView.ReuseID)
        } else if annotation is CellClusterAnnotation {
            return CellClusterAnnotationView(annotation: annotation, reuseIdentifier: CellClusterAnnotationView.ReuseID)
        }
        
        // TODO: Sometimes simple red pins are shown but when they're are tapped they show a callout and turn into correct annotations.
        // We don't know why
        // See Dicussion: https://developer.apple.com/documentation/mapkit/mkmapviewdelegate/1452045-mapview
        return nil
    }
    
    func mapView(_ mapView: MKMapView, clusterAnnotationForMemberAnnotations memberAnnotations: [MKAnnotation]) -> MKClusterAnnotation {
        if memberAnnotations.first is CellAnnotation {
            return CellClusterAnnotation(memberAnnotations: memberAnnotations)
        } else if memberAnnotations.first is LocationAnnotation {
            return LocationClusterAnnotation(memberAnnotations: memberAnnotations)
        }
        
        return MKClusterAnnotation(memberAnnotations: memberAnnotations)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let reachOverlay = overlay as? CellReachOverlay {
            let renderer = MKCircleRenderer(circle: reachOverlay.circle)
            // TODO: Base color on the current color scheme
            renderer.fillColor = UIColor.white.withAlphaComponent(0.08)
            return renderer
        }
        
        return MKOverlayRenderer(overlay: overlay)
    }
    
}
