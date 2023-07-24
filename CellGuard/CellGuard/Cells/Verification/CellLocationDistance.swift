//
//  CellLocationDistance.swift
//  CellGuard
//
//  Created by Lukas Arnold on 03.02.23.
//

import CoreLocation

struct CellLocationDistance {
    
    // The distance in meter between the user's location and the location from ALS
    let distance: CLLocationDistance
    // The horizontal accuracy in meters of the user's location
    let userAccuracy: CLLocationDistance
    // The speed of the user in meters per seconds
    let userSpeed: Double
    // The accuracy returned from ALS
    let alsAccuracy: CLLocationDistance
    
    let userLocationBackground: Bool
    let preciseBackground: Bool
    
    func correctedDistance() -> Double {
        // The absolute maximum reach of a cell tower is about 75km, so we subtract it from the distance
        let cellMaxReach = 75_000.0
        // We subtract the inaccuracies of the location measurements from the distance
        let inaccuracies = userAccuracy + alsAccuracy
        // We subtract an additional error margin dependent on the user's speed
        // Some iPhones record negative speeds which can't be used with pow() as the function would produce a NaN which is dangerous.
        let speedMargin: Double
        if userSpeed.isFinite && userSpeed > 0 {
            let userSpeedKmH = userSpeed * 3.6
            speedMargin = pow((userSpeedKmH / 2.0), 1.1) * 1000.0
        } else {
            speedMargin = 0
        }
        
        // Subtract all the possible error margins from the original distance calculated
        return (distance - cellMaxReach - inaccuracies - speedMargin)
    }
    
    func score() -> Double {
        // Sources:
        // - https://dgtlinfra.com/cell-tower-range-how-far-reach/
        // - https://en.wikipedia.org/wiki/Cell_site#Operation
        
        // Calculate a percentage how likely it is that the cell's location is too far away based on the distance and the user's speed.
        // We divide a corrected distance (with error margins) by 150km, the absolute maximum error tolerance, to get a percentage.
        // If it's below zero, the cell at its right place.
        // If it's larger than 50%, we're sure that even with all of our margin, the cell is more than 75km away from its ALS location, and thus a possible threat.
        let score = self.correctedDistance() / 150_000
        
        // The score should be within the range [0,1]
        if score > 1 {
            return 1
        } else if score < 0 {
            return 0
        } else {
            return score
        }
    }
    
    static func distance(userLocation: UserLocation, alsLocation: ALSLocation) -> CellLocationDistance {
        let clUserLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let clAlsLocation = CLLocation(latitude: alsLocation.latitude, longitude: alsLocation.longitude)
        
        return CellLocationDistance(
            distance: clUserLocation.distance(from: clAlsLocation),
            userAccuracy: userLocation.horizontalAccuracy,
            userSpeed: userLocation.speed,
            alsAccuracy: alsLocation.horizontalAccuracy,
            userLocationBackground: userLocation.background,
            preciseBackground: userLocation.preciseBackground
        )
    }
    
}
