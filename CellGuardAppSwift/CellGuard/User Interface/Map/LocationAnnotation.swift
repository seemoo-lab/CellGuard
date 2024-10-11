//
//  LocationAnnotation.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.01.23.
//

import CoreData
import Foundation
import MapKit

class LocationAnnotation: NSObject, MKAnnotation, DatabaseAnnotation {
    
    let coreDataID: NSManagedObjectID
    
    @objc dynamic let coordinate: CLLocationCoordinate2D
    
    init(location: LocationUser) {
        coreDataID = location.objectID
        coordinate = CLLocationCoordinate2D(
            latitude: location.latitude,
            longitude: location.longitude
        )
        // TODO: Also store accuracy?
    }
    
}
