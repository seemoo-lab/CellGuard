//
//  LDMLocation.swift
//  CellGuard
//
//  Created by Lukas Arnold on 08.01.23.
//

import Foundation
import CoreLocation

/// A structure similar to the model "Location".
struct LDMLocation: Persistable {
    
    init(from location: CLLocation) {
        self.coordinateLatitude = location.coordinate.latitude
        self.coordinateLongitude = location.coordinate.longitude
        self.horizontalAccuracy = location.horizontalAccuracy
        
        self.altitude = location.altitude
        self.verticalAccuracy = location.verticalAccuracy

        self.timestamp = location.timestamp
    }
    
    var coordinateLatitude: Double?
    var coordinateLongitude: Double?
    var horizontalAccuracy: Double?
    
    var altitude: Double?
    var verticalAccuracy: Double?
    
    var timestamp: Date?
    
    func asDictionary() -> [String : Any] {
        return [
            "coordinateLatitude": coordinateLatitude as Any,
            "coordinateLongitude": coordinateLongitude as Any,
            "horizontalAccuracy": horizontalAccuracy as Any,
            "altitude": altitude as Any,
            "verticalAccuracy": verticalAccuracy as Any,
            "timestamp": timestamp as Any
        ]
    }
    
}
