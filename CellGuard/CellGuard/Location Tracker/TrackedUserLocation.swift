//
//  LDMLocation.swift
//  CellGuard
//
//  Created by Lukas Arnold on 08.01.23.
//

import Foundation
import CoreLocation

private struct LocationDictKeys {
    
    static let latitude = "latitude"
    static let longitude = "longitude"
    static let horizontalAccuracy = "horizontalAccuracy"
    static let altitude = "altitude"
    static let verticalAccuracy = "verticalAccuracy"
    static let collected = "collected"
    
}

/// A structure similar to the model "Location".
struct TrackedUserLocation {
    
    var latitude: Double?
    var longitude: Double?
    var horizontalAccuracy: Double?
    
    var altitude: Double?
    var verticalAccuracy: Double?
    
    var timestamp: Date?
    
    init(from location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.horizontalAccuracy = location.horizontalAccuracy
        
        self.altitude = location.altitude
        self.verticalAccuracy = location.verticalAccuracy
        
        self.timestamp = location.timestamp
    }
    
    init(from location: UserLocation) {
        self.latitude = location.latitude
        self.longitude = location.longitude
        self.horizontalAccuracy = location.horizontalAccuracy
        
        self.altitude = location.altitude
        self.verticalAccuracy = location.verticalAccuracy
        
        self.timestamp = location.collected
    }
    
    init(from location: [String : Any]) {
        self.latitude = location[LocationDictKeys.latitude] as? Double
        self.longitude = location[LocationDictKeys.longitude] as? Double
        self.horizontalAccuracy = location[LocationDictKeys.horizontalAccuracy] as? Double
        
        self.altitude = location[LocationDictKeys.altitude] as? Double
        self.verticalAccuracy = location[LocationDictKeys.verticalAccuracy] as? Double
        
        if let timeSince1970 = location[LocationDictKeys.collected] as? Double {
            self.timestamp = Date(timeIntervalSince1970: timeSince1970)
        } else {
            self.timestamp = nil
        }
    }
    
    func applyTo(location: UserLocation) {
        location.latitude = self.latitude ?? 0
        location.longitude = self.longitude ?? 0
        location.horizontalAccuracy = self.horizontalAccuracy ?? 0
        
        location.altitude = self.altitude ?? 0
        location.verticalAccuracy = self.verticalAccuracy ?? 0
        
        location.collected = self.timestamp
    }
    
    func toDictionary() -> Dictionary<String, Any> {
        return [
            LocationDictKeys.latitude: latitude ?? 0,
            LocationDictKeys.longitude: longitude ?? 0,
            LocationDictKeys.horizontalAccuracy: horizontalAccuracy ?? 0,
            LocationDictKeys.altitude: altitude ?? 0,
            LocationDictKeys.verticalAccuracy: verticalAccuracy ?? 0,
            LocationDictKeys.collected: (timestamp ?? Date.distantPast).timeIntervalSince1970,
        ]
    }
    
}
