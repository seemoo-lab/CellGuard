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
    let userSpeed: Double
    let alsAccuracy: CLLocationDistance
    
    let userLocationBackground: Bool
    let preciseBackground: Bool
    
    func score() -> Double {
        // Sources:
        // - https://dgtlinfra.com/cell-tower-range-how-far-reach/
        // - https://en.wikipedia.org/wiki/Cell_site#Operation
        
        // Calculate a percentage how likely it is that the cell's location is too far away based on the distance and the user's speed.
        // The absolute maximum reach of a cell tower is about 75km, so we subtract it from the distance.
        // We also subtract the inaccuracies of the location measurements and we subtract an additional margin dependent on the user's speed.
        // This results in a number of kilometers that we divide by 150km, the absolute maximum error tolerance, to get a percentage.
        // If it's below zero, the cell at its right place.
        // If it's larger than 50%, we're sure that even with all of our margin, the cell is more than 75km away from its ALS location, and thus a possible threat.
        let score = (distance - 75_000 - userAccuracy - alsAccuracy - pow((userSpeed / 2.0), 1.1) * 1000) / 150
        
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
