//
//  LDMLocation.swift
//  CellGuard
//
//  Created by Lukas Arnold on 08.01.23.
//

import Foundation
import CoreLocation

/// A structure similar to the model "Location".
struct LDMLocation {
    
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
    
    func applyTo(location: UserLocation) {
        location.latitude = self.coordinateLatitude ?? 0
        location.longitude = self.coordinateLongitude ?? 0
        location.horizontalAccuracy = self.horizontalAccuracy ?? 0
        
        location.altitude = self.altitude ?? 0
        location.verticalAccuracy = self.verticalAccuracy ?? 0
        
        location.collected = self.timestamp
    }
    
}
