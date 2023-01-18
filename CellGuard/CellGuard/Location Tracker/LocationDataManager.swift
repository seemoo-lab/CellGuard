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
        category: String(describing: LocationDataManager.self)
    )
    
    private let locationManager = CLLocationManager()
    private var authorizationCompletion: ((Bool) -> Void)?
    
    let extact: Bool
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastLocation: CLLocation?
    
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
        
        Self.logger.log("Authorization: \(self.describe(authorizationStatus: manager.authorizationStatus))")
        authorizationStatus = manager.authorizationStatus
        
        if authorizationStatus == .authorizedWhenInUse && authorizationCompletion != nil {
            // The second part of the request the always authorization, see below in requestAuthorization()
            locationManager.requestAlwaysAuthorization()
            
            // Solution for missing callback copied from AirGuard:
            
            // If the user prevously selected "Allow once" for location, no dialogue will appear when requesting always usage.
            // We detect if a dialogue is shown using the background property.
            // If the dialogue is show, the app is in background.
            // If not, we open the app settings.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                print("After 0.5s: \(BackgroundState.shared.inBackground)")
                if !BackgroundState.shared.inBackground {
                    print("Alright")
                    self.authorizationCompletion?(false)
                    self.authorizationCompletion = nil
                }
            })
            return
        }
        
        authorizationCompletion?(authorizationStatus == .authorizedAlways)
        authorizationCompletion = nil
        
        // More information about the always status which is also temporarily granted if only requestAlwaysAuthorization is called:
        // https://developer.apple.com/forums/thread/117256?page=2
        if manager.authorizationStatus == .authorizedAlways {
            resumeLocationUpdates()
        }
    }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        self.authorizationCompletion = completion
        // First we have to request, when in use authorization.
        // When we've got the permission, we can request always authorization.
        // https://developer.apple.com/documentation/corelocation/cllocationmanager/1620551-requestalwaysauthorization
        locationManager.requestWhenInUseAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Self.logger.log("New Locations: \(locations)")
        
        let importLocations = locations.map { LDMLocation(from: $0) }
        
        do {
            try PersistenceController.shared.importLocations(from: importLocations)
        } catch {
            Self.logger.warning("Can't save locations: \(error)\nLocations: \(locations)")
        }
        
        if !locations.isEmpty {
            self.lastLocation = locations.last
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        Self.logger.log("New Visit: \(visit)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Self.logger.warning("Location Error: \(error)")
    }
    
    private func resumeLocationUpdates() {
        if extact {
            locationManager.startUpdatingLocation()
        }
        
        // https://developer.apple.com/documentation/corelocation/cllocationmanager/1423531-startmonitoringsignificantlocati
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startMonitoringVisits()
    }
    
    private func describe(authorizationStatus: CLAuthorizationStatus) -> String {
        switch (authorizationStatus) {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        
        default:
            return "unknwon (\(authorizationStatus.rawValue)"
        }
    }
}
