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
    
    let onTap: (NSManagedObjectID) -> Void
    
    init(onTap: @escaping (NSManagedObjectID) -> Void) {
        self.onTap = onTap
        super.init()
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if let annotation = view.annotation as? CellAnnotation {
            onTap(annotation.coreDataID)
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is CellAnnotation {
            // TODO: Sometimes red pins are shown instead of this
            return CellAnnotationView(annotation: annotation, reuseIdentifier: CellAnnotationView.ReuseID)
        } else if annotation is LocationAnnotation {
            return LocationAnnotationView(annotation: annotation, reuseIdentifier: LocationAnnotationView.ReuseID)
        } else if annotation is CellClusterAnnotation {
            return CellClusterAnnotationView(annotation: annotation, reuseIdentifier: CellClusterAnnotationView.ReuseID)
        } else if annotation is LocationClusterAnnotation {
            return LocationAnnotationView(annotation: annotation, reuseIdentifier: LocationAnnotationView.ReuseID)
        }
        
        // TODO: When is this returned?
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
    
}
