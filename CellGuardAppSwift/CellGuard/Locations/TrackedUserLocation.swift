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
    static let speed = "speed"
    static let speedAccuracy = "speedAccuracy"
    static let collected = "collected"
    static let background = "background"
    static let preciseBackground = "preciseBackground"

}

/// A structure similar to the model "Location".
struct TrackedUserLocation {

    var latitude: Double?
    var longitude: Double?
    var horizontalAccuracy: Double?

    var altitude: Double?
    var verticalAccuracy: Double?

    var speed: Double?
    var speedAccuracy: Double?

    var timestamp: Date?

    var background: Bool
    var preciseBackground: Bool

    init(from location: CLLocation, background: Bool, preciseBackground: Bool) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.horizontalAccuracy = location.horizontalAccuracy

        self.altitude = location.altitude
        self.verticalAccuracy = location.verticalAccuracy

        self.speed = location.speed
        self.speedAccuracy = location.speedAccuracy

        self.timestamp = location.timestamp

        self.background = background
        self.preciseBackground = preciseBackground
    }

    init(from location: LocationUser) {
        self.latitude = location.latitude
        self.longitude = location.longitude
        self.horizontalAccuracy = location.horizontalAccuracy

        self.altitude = location.altitude
        self.verticalAccuracy = location.verticalAccuracy

        self.speed = location.speed
        self.speedAccuracy = location.speedAccuracy

        self.timestamp = location.collected

        self.background = location.background
        self.preciseBackground = location.preciseBackground
    }

    init(from location: [String: Any]) {
        self.latitude = location[LocationDictKeys.latitude] as? Double
        self.longitude = location[LocationDictKeys.longitude] as? Double
        self.horizontalAccuracy = location[LocationDictKeys.horizontalAccuracy] as? Double

        self.altitude = location[LocationDictKeys.altitude] as? Double
        self.verticalAccuracy = location[LocationDictKeys.verticalAccuracy] as? Double

        self.speed = location[LocationDictKeys.speed] as? Double
        self.speedAccuracy = location[LocationDictKeys.speedAccuracy] as? Double

        if let timeSince1970 = location[LocationDictKeys.collected] as? Double {
            self.timestamp = Date(timeIntervalSince1970: timeSince1970)
        } else {
            self.timestamp = nil
        }

        self.background = location[LocationDictKeys.background] as? Bool ?? true
        self.preciseBackground = location[LocationDictKeys.preciseBackground] as? Bool ?? false
    }

    init(timestamp: Date, latitude: Double, longitude: Double, horizontalAccuracy: Double, altitude: Double, verticalAccuracy: Double, speed: Double, speedAccuracy: Double, background: Bool) {
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy

        self.altitude = altitude
        self.verticalAccuracy = verticalAccuracy

        self.speed = speed
        self.speedAccuracy = speedAccuracy

        self.timestamp = timestamp

        self.background = background
        self.preciseBackground = true
    }

    func applyTo(location: LocationUser) {
        location.latitude = self.latitude ?? 0
        location.longitude = self.longitude ?? 0
        location.horizontalAccuracy = self.horizontalAccuracy ?? 0

        location.altitude = self.altitude ?? 0
        location.verticalAccuracy = self.verticalAccuracy ?? 0

        location.speed = self.speed ?? 0
        location.speedAccuracy = self.speedAccuracy ?? 0

        location.collected = self.timestamp

        location.background = background
        location.preciseBackground = preciseBackground
    }

    func toDictionary() -> [String: Any] {
        return [
            LocationDictKeys.latitude: latitude ?? 0,
            LocationDictKeys.longitude: longitude ?? 0,
            LocationDictKeys.horizontalAccuracy: horizontalAccuracy ?? 0,
            LocationDictKeys.altitude: altitude ?? 0,
            LocationDictKeys.verticalAccuracy: verticalAccuracy ?? 0,
            LocationDictKeys.speed: speed ?? 0,
            LocationDictKeys.speedAccuracy: speedAccuracy ?? 0,
            LocationDictKeys.collected: timestamp?.timeIntervalSince1970 ?? 0,
            LocationDictKeys.background: background,
            LocationDictKeys.preciseBackground: preciseBackground
        ]
    }

}
