//
//  LocationDataManager.swift
//  CellGuard
//
//  Created by Lukas Arnold on 02.01.23.
//

import Combine
import CoreLocation
import OSLog

class LocationDataManagerPublished: NSObject, ObservableObject {

    public static var shared = LocationDataManagerPublished()

    private override init() {
        super.init()
    }

    @Published var authorizationStatus: CLAuthorizationStatus?
    @Published var lastLocation: CLLocation?

    var authorized: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }

}

class LocationDataManager: NSObject, CLLocationManagerDelegate {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: LocationDataManager.self)
    )

    public static var shared = LocationDataManager()

    private let locationManager = CLLocationManager()
    private var authorizationCompletion: ((Bool) -> Void)?
    private var background = true
    private var verificationApproachSink: AnyCancellable?

    private override init() {
        super.init()

        locationManager.delegate = self
        // TODO: We could disable background location updates if the app is in the analysis & manual modes to save battery
        // -> Which accuracy for the locations if the app is in background? (Important for manual mode)
        // -> We have to listen for changes of the mode to dis- or enable this setting
        locationManager.allowsBackgroundLocationUpdates = true
        // TODO: Can we use a distance filter to reduce the number of location updates?
        // -> Then we would have to update our location assignment algorithm
        // locationManager.distanceFilter = 10

        updateAccuracy()

        // Properties that could be interesting
        // https://developer.apple.com/documentation/corelocation/cllocationmanager/1620553-pauseslocationupdatesautomatical
        // https://developer.apple.com/documentation/corelocation/cllocationmanager/1620567-activitytype

        // Useful for later (UI)
        // https://developer.apple.com/documentation/corelocation/converting_between_coordinates_and_user-friendly_place_names
     }

    deinit {
        verificationApproachSink?.cancel()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // https://developer.apple.com/documentation/corelocation/configuring_your_app_to_use_location_services
        // https://developer.apple.com/documentation/corelocation/requesting_authorization_to_use_location_services
        // https://developer.apple.com/documentation/corelocation/handling_location_updates_in_the_background

        Self.logger.log("Authorization: \(self.describe(authorizationStatus: manager.authorizationStatus))")

        DispatchQueue.main.async {
            LocationDataManagerPublished.shared.authorizationStatus = manager.authorizationStatus
        }

        if manager.authorizationStatus == .authorizedWhenInUse && authorizationCompletion != nil {
            requestAlwaysAuthorization()
            return
        }

        DispatchQueue.main.async {
            self.authorizationCompletion?(manager.authorizationStatus == .authorizedAlways)
            self.authorizationCompletion = nil
        }

        // More information about the always status which is also temporarily granted if only requestAlwaysAuthorization is called:
        // https://developer.apple.com/forums/thread/117256?page=2
        if manager.authorizationStatus == .authorizedAlways {
            resumeLocationUpdates()
        }
    }

    private func requestAlwaysAuthorization() {
        // The second part of the request the always authorization, see below in requestAuthorization()
        locationManager.requestAlwaysAuthorization()

        // Solution for missing callback copied from AirGuard:

        // If the user previously selected "Allow once" for location, no dialogue will appear when requesting always usage.
        // We detect if a dialogue is shown using the background property.
        // If the dialogue is show, the app is in background.
        // If not, we open the app settings.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            if !BackgroundState.shared.inBackground {
                self.authorizationCompletion?(false)
                self.authorizationCompletion = nil
            }
        })
        return
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        // If the user denied the authorization, return false
        let authorizationStatus = LocationDataManagerPublished.shared.authorizationStatus
        if authorizationStatus == .denied || authorizationStatus == .restricted {
            completion(false)
            return
        }

        // If we already received the authorization, we can instantly return true
        if authorizationStatus == .authorizedAlways {
            completion(true)
            return
        }

        self.authorizationCompletion = completion

        // First we have to request, when in use authorization.
        // When we've got the permission, we can request always authorization.
        // https://developer.apple.com/documentation/corelocation/cllocationmanager/1620551-requestalwaysauthorization

        if authorizationStatus == .authorizedWhenInUse {
            // We can skip requesting the when-in-authorization if it has already been granted
            requestAlwaysAuthorization()
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Don't import locations if the analysis mode is active
        guard UserDefaults.standard.dataCollectionMode() != .none else { return }

        Self.logger.log("New Locations: \(locations)")

        DispatchQueue.global(qos: .background).async {
            let importLocations = locations.map { TrackedUserLocation(from: $0, background: self.background, preciseBackground: true) }
            do {
                try PersistenceController.shared.importUserLocations(from: importLocations)
            } catch {
                Self.logger.warning("Can't save locations: \(error)\nLocations: \(locations)")
            }
        }

        if let localLastLocation = locations.max(by: { $0.timestamp < $1.timestamp }) {
            DispatchQueue.main.async {
                LocationDataManagerPublished.shared.lastLocation = localLastLocation
            }

            updateAccuracy(location: localLastLocation)
        }
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        // Don't import visits if the analysis mode is active
        guard UserDefaults.standard.dataCollectionMode() != .none else { return }

        Self.logger.log("New Visit: \(visit)")

        // TODO: Also record visits as locations
        // Question: Do we already get the same data from background location updates?
        // See: https://www.kodeco.com/5247-core-location-tutorial-for-ios-tracking-visited-locations
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Self.logger.warning("Location Error: \(error)")
    }

    private func resumeLocationUpdates() {
        locationManager.startUpdatingLocation()

        // https://developer.apple.com/documentation/corelocation/cllocationmanager/1423531-startmonitoringsignificantlocati
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startMonitoringVisits()
    }

    private func describe(authorizationStatus: CLAuthorizationStatus) -> String {
        switch authorizationStatus {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"

        default:
            return "unknown (\(authorizationStatus.rawValue)"
        }
    }

    // TODO: Add new UserDefault which allows for more fine-grained tracking
    // Foreground -> Similar (kCLLocationAccuracyBest)
    // Background (Slow moving) -> kCLLocationAccuracyKilometer
    // Background (Fast moving) -> kCLLocationAccuracyBestForNavigation
    // See: https://developer.apple.com/documentation/corelocation/cllocationmanager/1423836-desiredaccuracy
    // See: https://developer.apple.com/forums/thread/69152?answerId=202430022#202430022

    func enterForeground() {
        background = false
        if locationManager.authorizationStatus == .authorizedAlways ||
        locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()
            updateAccuracy()
        }
    }

    func enterBackground() {
        background = true
        updateAccuracy()
    }

    private func updateAccuracy() {
        updateAccuracy(location: LocationDataManagerPublished.shared.lastLocation)
    }

    private func updateAccuracy(location: CLLocation?) {
        // It's our choice with the Always permission whether we display the indicator or not
        // See: https://developer.apple.com/documentation/corelocation/handling_location_updates_in_the_background
        // We allow the user to chose whether the indicator is shown or not, by default it's hidden.
        locationManager.showsBackgroundLocationIndicator = UserDefaults.standard.bool(forKey: UserDefaultsKeys.showTrackingMarker.rawValue)

        if !background {
            Self.logger.debug("Accuracy -> Best")
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            return
        }

        #if !JAILBREAK
        // Reduce the location accuracy if the lower power is active to preserve battery.
        // We don't require the location during those times as the device does not collect debug data (including cells & packets) if the mode is active.
        // See: https://developer.apple.com/documentation/foundation/processinfo/1617047-islowpowermodeenabled
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            Self.logger.debug("Accuracy -> ThreeKilometers (Low Power Mode)")
            locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            return
        }
        #endif

        // https://stackoverflow.com/a/3460632
        // https://developer.apple.com/documentation/corelocation/cllocationmanager/1620553-pauseslocationupdatesautomatical
        if (location?.speed ?? 0) > 15 {
            Self.logger.debug("Accuracy -> NearestTenMeters")
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        } else {
            Self.logger.debug("Accuracy -> HundredMeters")
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        }
    }
}
