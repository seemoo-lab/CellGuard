//
//  LocationDataManager.swift
//  CellGuard
//
//  Created by Lukas Arnold on 02.01.23.
//

import Foundation
import CoreLocation
import OSLog

class LocationDataManager : NSObject, CLLocationManagerDelegate, ObservableObject {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ALSClient.self)
    )
    private let locationManager = CLLocationManager()
    
    let extact: Bool
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
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
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedAlways {
            resumeLocationUpdates()
        }
    }
    
    func requestAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Self.logger.log("New Locations: \(locations)")
        
        let importLocations = locations.map { LDMLocation(from: $0) }
        
        do {
            try PersistenceController.shared.importLocations(from: importLocations)
        } catch {
            Self.logger.warning("Can't save locations: \(error)\nLocations: \(locations)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        Self.logger.log("New Visit: \(visit)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Self.logger.warning("Location Error: \(error)")
    }
    
    private func resumeLocationUpdates() {
        // TODO: Do these function calls clash?
        if extact {
            locationManager.startUpdatingLocation()
        }
        
        // https://developer.apple.com/documentation/corelocation/cllocationmanager/1423531-startmonitoringsignificantlocati
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startMonitoringVisits()
    }
}
