//
//  CellLocationDistance.swift
//  CellGuard
//
//  Created by Lukas Arnold on 03.02.23.
//

import CoreLocation

enum CellRangeVerification {
    case ok
    case warning
    case failure
}

struct CellLocationDistance {
    
    let distance: CLLocationDistance
    let userAccuracy: CLLocationDistance
    let alsAccuracy: CLLocationDistance
    
    let userLocationBackground: Bool
    let preciseBackground: Bool
    
    func largerThan(maximum: CLLocationDistance) -> Bool {
        return distance > maximum + userAccuracy + alsAccuracy
    }
    
    func verify() -> CellRangeVerification {
        // Sources:
        // - https://dgtlinfra.com/cell-tower-range-how-far-reach/
        // - https://en.wikipedia.org/wiki/Cell_site#Operation
        
        // The absolute maximum reach of a cell tower is about 70km
        let maxCellReach = 70_000.0
        
        // TODO: Calculate maximum range based on the cellular technology & speed of assigned location
        
        // If we've got a continous stream of locations, we scan be much more fine-grained with distances.
        let preciseWarning = 20_000.0
        let preciseFailure = maxCellReach
        
        // If we're only getting occasional from the iPhone, users can travel a lot of kilometers until we get the next location.
        // Thus, we have to incooperate a large margin of error to decrase false positives.
        let inpreciseWarning = 150_000.0
        let inpreciseFailure = 200_000.0
        
        print("Distance is \(distance)")
        
        if userLocationBackground && !preciseBackground {
            // Use higher margins for warning if the location has been recorded in background with a bad accuracy
            if largerThan(maximum: inpreciseFailure) {
                return .failure
            } else if largerThan(maximum: inpreciseWarning) {
                return .warning
            }
        } else {
            // Use smaller margins as the location either has been recorded in foreground or with a high accuracy in background
            if largerThan(maximum: preciseFailure) {
                return .failure
            } else if largerThan(maximum: preciseWarning) {
                return .warning
            }
        }
        
        return .ok
    }
    
    static func distance(userLocation: UserLocation, alsLocation: ALSLocation) -> CellLocationDistance {
        let clUserLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let clAlsLocation = CLLocation(latitude: alsLocation.latitude, longitude: alsLocation.longitude)

        return CellLocationDistance(
            distance: clUserLocation.distance(from: clAlsLocation),
            userAccuracy: userLocation.horizontalAccuracy,
            alsAccuracy: alsLocation.horizontalAccuracy,
            userLocationBackground: userLocation.background,
            preciseBackground: userLocation.preciseBackground
        )
    }
    
}
