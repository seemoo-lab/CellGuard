//
//  CellMapDelegate.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.01.23.
//

import CoreData
import Foundation
import MapKit
import OSLog

class CellMapDelegate: NSObject, MKMapViewDelegate {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CellMapDelegate.self)
    )
    
    let onTap: ((NSManagedObjectID) -> Void)?
    let clustering: Bool
    
    init(onTap: ((NSManagedObjectID) -> Void)? = nil, clustering: Bool = true) {
        self.onTap = onTap
        self.clustering = clustering
        super.init()
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if let annotation = view.annotation as? CellAnnotation {
            onTap?(annotation.coreDataID)
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? CellAnnotation {
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: CellAnnotationView.ReuseID, for: annotation)
            if let view = view as? CellAnnotationView {
                // We have to update the annotation view here to display it with the correct properties,
                // because in its prepareForReuse() method, there's no annotation data available and
                // updating its properties in the prepareForDisplay() method is too late.
                view.calloutAccessory = onTap != nil
                view.updateColor(technology: annotation.technology)
                
                // Set clustering identifier to nil to prevent clustering
                if !clustering {
                    view.clusteringIdentifier = nil
                }
            }
            return view
        } else if annotation is LocationAnnotation {
            return mapView.dequeueReusableAnnotationView(withIdentifier: LocationAnnotationView.ReuseID, for: annotation)
        } else if let annotation = annotation as? TowerAnnotation {
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: TowerAnnotationView.ReuseID, for: annotation)
            if let view = view as? TowerAnnotationView {
                // Same reasoning as for CellAnnotation
                view.updateColor(technology: annotation.technology)
            }
            return view
        } else if annotation is LocationClusterAnnotation {
            // I assume we have to use a separate identifier for the cluster view, otherwise we get a crash
            // See: https://forums.developer.apple.com/forums/thread/89427
            return mapView.dequeueReusableAnnotationView(withIdentifier: LocationAnnotationView.ClusterReuseID, for: annotation)
        } else if annotation is CellClusterAnnotation {
            return mapView.dequeueReusableAnnotationView(withIdentifier: CellClusterAnnotationView.ReuseID, for: annotation)
        } else if annotation is MKUserLocation {
            // We can return nil as MapKit takes care of drawing this annotation
            return nil
        }
        
        // TODO: Sometimes simple red pins are shown but when they're are tapped they show a callout and turn into correct annotations.
        // We don't know why
        // See Discussion: https://developer.apple.com/documentation/mapkit/mkmapviewdelegate/1452045-mapview
        
        Self.logger.warning("Annotation view for unknown annotation type: \(String(describing: annotation.self))")
        return nil
    }
    
    func mapView(_ mapView: MKMapView, clusterAnnotationForMemberAnnotations memberAnnotations: [MKAnnotation]) -> MKClusterAnnotation {
        if memberAnnotations.first is CellAnnotation {
            return CellClusterAnnotation(memberAnnotations: memberAnnotations)
        } else if memberAnnotations.first is LocationAnnotation {
            return LocationClusterAnnotation(memberAnnotations: memberAnnotations)
        }
        
        Self.logger.warning("Cluster annotation for unknown annotation type: \(String(describing: memberAnnotations.first.self))")
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
