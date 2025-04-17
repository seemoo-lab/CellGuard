//
//  CellRadiusOverlay.swift
//  CellGuard
//
//  Created by Lukas Arnold on 29.01.23.
//

import MapKit
import CoreData

class CellReachOverlay: NSObject, MKOverlay {

    let coreDataID: NSManagedObjectID
    let circle: MKCircle

    var coordinate: CLLocationCoordinate2D {
        get {
            circle.coordinate
        }
    }

    var boundingMapRect: MKMapRect {
        get {
            circle.boundingMapRect
        }
    }

    init(location: LocationALS) {
        // TODO: Measure & Improve performance
        coreDataID = location.objectID
        circle = MKCircle(
            center: CLLocationCoordinate2D(
                latitude: location.latitude,
                longitude: location.longitude
            ),
            radius: Double(location.reach)
        )
    }

    func intersects(_ mapRect: MKMapRect) -> Bool {
        return circle.intersects(mapRect)
    }

}
