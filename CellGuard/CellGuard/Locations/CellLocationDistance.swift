//
//  CellLocationDistance.swift
//  CellGuard
//
//  Created by Lukas Arnold on 03.02.23.
//

import CoreLocation

struct CellLocationDistance {
    
    let distance: CLLocationDistance
    let userAccuracy: CLLocationDistance
    let alsAccuracy: CLLocationDistance
    
    private init(distance: CLLocationDistance, userAccuracy: CLLocationDistance, alsAccuracy: CLLocationDistance) {
        self.distance = distance
        self.userAccuracy = userAccuracy
        self.alsAccuracy = alsAccuracy
    }
    
    func largerThan(maximum: CLLocationDistance) -> Bool {
        return distance + userAccuracy + alsAccuracy > maximum
    }
    
    static func distance(userLocation: UserLocation, alsLocation: ALSLocation) -> CellLocationDistance {
        let clUserLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let clAlsLocation = CLLocation(latitude: alsLocation.latitude, longitude: alsLocation.longitude)

        return CellLocationDistance(
            distance: clUserLocation.distance(from: clAlsLocation),
            userAccuracy: userLocation.horizontalAccuracy,
            alsAccuracy: alsLocation.horizontalAccuracy
        )
    }
    
}
