//
//  LocationDataManager.swift
//  CellGuard
//
//  Created by Lukas Arnold on 02.01.23.
//

import Foundation
import CoreLocation
import OSLog

class LocationDataManger : NSObject, CLLocationManagerDelegate {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ALSClient.self)
    )
    private let locationManager = CLLocationManager()
    
    let extact: Bool
    
    // TODO: Initialize in app
    init(extact: Bool) {
        self.extact = extact
        
        super.init()
        
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        // Properties that could be interesting
        // https://developer.apple.com/documentation/corelocation/cllocationmanager/1620553-pauseslocationupdatesautomatical
        // https://developer.apple.com/documentation/corelocation/cllocationmanager/1620567-activitytype
        
        // Useful for later (UI)
        // https://developer.apple.com/documentation/corelocation/converting_between_coordinates_and_user-friendly_place_names
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // https://developer.apple.com/documentation/corelocation/configuring_your_app_to_use_location_services
        // https://developer.apple.com/documentation/corelocation/requesting_authorization_to_use_location_services
        // https://developer.apple.com/documentation/corelocation/handling_location_updates_in_the_background
        
        Self.logger.log("Authorization: \(manager.authorizationStatus.rawValue)")
        if manager.authorizationStatus == .notDetermined {
            manager.requestAlwaysAuthorization()
        } else if manager.authorizationStatus == .authorizedAlways {
            self.resumeLocationUpdates(extact: self.extact)
        }
        // TODO: Handle other casees -> Callback to show specific views
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Self.logger.log("New Location: \(locations)")
        
        // TODO: View or Background context?
        let context = PersistenceController.shared.container.viewContext
        
        locations.forEach { location in
            let entity = Location(context: context)
            entity.altitude = location.altitude
            entity.verticalAccuracy = location.verticalAccuracy
            entity.coordinateLatitude = location.coordinate.latitude
            entity.coordinateLongitude = location.coordinate.longitude
            entity.horizontalAccuracy = entity.horizontalAccuracy
            entity.timestamp = location.timestamp
        }
        
        do {
            try context.save()
        } catch {
            Self.logger.warning("Couldn't save location data: \(error)\nLocations: \(locations)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        Self.logger.log("New Visit: \(visit)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Self.logger.warning("Location Error: \(error)")
    }
    
    private func resumeLocationUpdates(extact: Bool) {
        // TODO: Do these calls clash?
        if extact {
            locationManager.startUpdatingLocation()
        }
        
        // https://developer.apple.com/documentation/corelocation/cllocationmanager/1423531-startmonitoringsignificantlocati
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startMonitoringVisits()
    }
}
