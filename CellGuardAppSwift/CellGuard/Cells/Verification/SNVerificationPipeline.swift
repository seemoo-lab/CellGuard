//
//  SNVerificationPipeline.swift
//  CellGuard
//
//  Created by Lukas Arnold on 06.05.24.
//

import Foundation
import CoreData
import OSLog
import Dispatch
import CoreLocation

// TODO: Test if this refactored version of the pipeline works as intended
// If yes, reenable the pipeline by removing the comment in VerificationPipeline (line 15)

// Hint: Use a logger instead of print
private let pipelineLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: String(describing: SNVerificationPipeline.self)
)

extension Double {
    // Hint: Use camcelCase for variable names
    var degreesToRadians: Double {
        return self * .pi / 180.0
    }
}

private enum CountryCodeResult {
    case found(String)
    case none
    case error
}

private struct CompareableCLLocation: Hashable {
    let latitude: Double
    let longitude: Double
    
    func toCL() -> CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
}

// Cache for the country code to prevent unnecessary requests -> speed up + less rate-limit issues
private var countryCodeCache: [CompareableCLLocation : String] = [:]

// Hint: You can use async & await instead of semaphores
// Hint: You can use optionals to signal that a value is missing or if there are multiple return "cases" you can also use an enum.
private func getCountryCode(latitude: Double, longitude: Double) async -> CountryCodeResult {
    let location = CompareableCLLocation(latitude: latitude, longitude: longitude)
    
    // Hint: Cache stuff if you have to perform a web request for it etc.
    if let cacheResult = countryCodeCache[location] {
        return .found(cacheResult)
    }
    
    // ReverseGeocodeLocation performs an API call every time and is rate-limited.
    // The rate limiting is noticeable especially when importing a new sysdiagnose (see errors in console).
    // TODO: Can you either cache the results (more efficiently) or find another way to get the ISO code from coordinates (would be even better)?
    // Idea: You can trim the lat & lon values to 4 decimals places to reuse the cache more often and prevent unnecessary queries.
    //       This should be fine as CellGuard only requests locations with an accuracy of 10m.
    //       Cutting 4 decimals places results in such an accuracy (https://en.wikipedia.org/wiki/Decimal_degrees).
    //       You can use the Double.truncate method for this.
    // Idea: You are already loading the GeoJSON, maybe you can use it to determine the ISO from coordinates on-device
    // Feel free to include libraries to help you with that task.
    // Some I found on the Internet:
    // - https://github.com/kiliankoe/GeoJSON
    // - https://github.com/maparoni/GeoJSONKit
    // - https://github.com/Outdooractive/gis-tools (Looks very efficient for this task & the task below due to the R-tree)
    do {
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location.toCL())
        for placemark in placemarks {
            if let isoCountryCode = placemark.isoCountryCode {
                // TODO: Something is crashing here (I guess)
                countryCodeCache[location] = isoCountryCode
                return .found(isoCountryCode)
            }
        }
        
        return .none
    } catch {
        pipelineLogger.warning("Failed to get country code for (\(latitude), \(longitude)): \(error)")
        return .error
    }
}

// I've put the functionality to query the longitude & latitude in one function
// Hint: You can declare functions only intended for this file as private.
private func queryLatLong(_ queryCellId: NSManagedObjectID) -> (Double, Double)? {
    // Hint: You can return tuples, thus saving one additional DB request (they're expensive timewise)
    return PersistenceController.shared.fetchCellAttribute(cell: queryCellId) { cell -> (Double, Double)? in
        guard let location = cell.location else {
            return nil
        }
        return (location.latitude, location.longitude)
    }
}

private struct NoConnectionDummyStage: VerificationStage {
    
    var id: Int16 = 1
    var name: String = "No Connection Defaults"
    var description: String = "Skips default measurements present when there's no connection."
    var points: Int16 = 0
    var waitForPackets: Bool = false
    
    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        
        // In ARI devices, a cell ID larger than Int32.max for UMTS connections indicates no cellular connection.
        if queryCell.technology == .UMTS && queryCell.cell == 0xFFFFFFFF {
            return .finishEarly
        }
        
        return .success()
    }
}

private struct No3GConnectionStage: VerificationStage {
    
    var id: Int16 = 2
    var name: String = "No 3G Connection"
    var description: String = "Checks wether the phone is connected to a 3G Cell in a 'No-3G-Country'."
    var points: Int16 = 1
    var waitForPackets: Bool = false
    
    private let persistence = PersistenceController.shared
    
    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        // Hint: Use guard statements to simply & flatten your code
        guard queryCell.technology == .UMTS else {
            return .success()
        }
        
        // Update: Thanks to the changes you can assume that either a location has been assigned or none is available for this cell.
        // Hint: Feel free to extract common functionality into functions to make everything a bit cleaner
        guard let (latitude, longitude) = queryLatLong(queryCellId) else {
            // Hint: You can abort the pipeline early if a condition  (here: no location) is not but is required by every following stage
            return .finishEarly
        }
        
        switch await getCountryCode(latitude: latitude, longitude: longitude) {
        case let .found(cc):
            if ["DE", "NO", "LU", "CZ", "NL", "HU", "IT", "CY", "MT", "GR"].contains(cc) {
                return .fail()
            }
            return .success()
        case .error:
            // TODO: Is this delay a good idea?
            // I've added it because if the Geocoder exceeds its rate limit we have to wait until we can perform requests again.
            // Or is there also an error if there's no Internet, do we have to handle that separately?
            return .delay(seconds: 60)
        case .none:
            return .success()
        }
    }
}

private struct No2GConnectionStage: VerificationStage {
    
    var id: Int16 = 3
    var name: String = "No 2G Connection"
    var description: String = "Checks wether the phone is connected to a 2G Cell in a 'No-2G-Country'."
    var points: Int16 = 1
    var waitForPackets: Bool = false
    
    private let persistence = PersistenceController.shared
    
    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        guard queryCell.technology == .GSM else {
            return .success()
        }
        
        guard let (latitude, longitude) = queryLatLong(queryCellId) else {
            // Here we don't finish early because in theory the stage beforehand could have deducted points
            // (but this is very unlikely because once a user location is assigned to a cell it is never removed again)
            return .success()
        }
        
        switch await getCountryCode(latitude: latitude, longitude: longitude) {
        case let .found(cc):
            // ISO 3166 codes for countries, that reportedly, don't use GSM/2G anymore.
            if ["CH", "AU", "BH", "BN", "CN", "CO", "HK", "JP", "MX", "SG", "ZA", "KR", "TW", "AE", "US"].contains(cc) {
                return .fail()
            }
            return .success()
        case .error:
            return .delay(seconds: 60)
        case .none:
            return .success()
        }
    }
}



private struct CheckCorrectMCCStage: VerificationStage {
    
    var id: Int16 = 4
    var name: String = "Correct MCC"
    var description: String = "Checks wether the MCC is corresponded to the correct country."
    var points: Int16 = 1
    var waitForPackets: Bool = false
    
    private let persistence = PersistenceController.shared
    
    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        guard let (latitude, longitude) = queryLatLong(queryCellId) else {
            return .success()
        }
        
        switch await getCountryCode(latitude: latitude, longitude: longitude) {
        case let .found(cc):
            let operatorCountry = OperatorDefinitions.shared.translate(country: queryCell.country, iso: true)
            // Hint: Don't use the ! operator in production as the app will crash if there is a null value, instead it's better to handle both cases.
            guard let operatorCountry = operatorCountry else {
                return .success()
            }
            
            // Checks wether the translated MCC corresponds to the user's country code
            if operatorCountry.uppercased() == cc.uppercased() {
                return .success()
            } else {
                return .fail()
            }
        case .error:
            return .delay(seconds: 60)
        case .none:
            return .success()
        }
    }
}

private struct CheckCorrectMNCStage: VerificationStage {
    
    var id: Int16 = 5
    var name: String = "Correct MNC"
    var description: String = "Checks wether the MNC corresponds to the correct operator in the correct country."
    var points: Int16 = 1
    var waitForPackets: Bool = false
    
    private let persistence = PersistenceController.shared
    
    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        guard let (latitude, longitude) = queryLatLong(queryCellId) else {
            return .success()
        }
        
        switch await getCountryCode(latitude: latitude, longitude: longitude) {
        case let .found(cc):
            // TODO: Think if this stage is required or does it effectively perform the same check as the stage above?
            // To do this look at the source code of the OperatorDefinitions
            let (country, _) = OperatorDefinitions.shared.translate(country: queryCell.country, network: queryCell.network, iso: true)
            guard let country = country else {
                return .success()
            }
            
            // Checks wether the translated MNC corresponds to the user's country code
            if country.uppercased() == cc.uppercased() {
                return .success()
            } else {
                return .fail()
            }
        case .error:
            return .delay(seconds: 60)
        case .none:
            return .success()
        }
    }
}

private struct CheckDistanceOfCell: VerificationStage {
    
    var id: Int16 = 6
    var name: String = "Correct Distance of Cell"
    var description: String = "Checks wether it is possible, that a user is near a country boarder, thus connecting to a different MCC."
    var points: Int16 = 1
    var waitForPackets: Bool = false
    
    // Hint: Only perform disk operations once if you to save time during the stage's execution
    // If we use a static variable, the file is lazily loaded, i.e. only if required (see https://stackoverflow.com/a/34667272)
    private static var countryBorders = Self.loadGeoJson()
    
    private static func loadGeoJson() -> [String: [[CLLocationCoordinate2D]]]? {
        guard let path = Bundle.main.path(forResource: "countries.geojson", ofType: "gz") else {
            pipelineLogger.warning("Can't find countries.geojson.gz")
            return nil
        }
        
        let geoJson: Any
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path)).gunzipped()
            geoJson = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            pipelineLogger.warning("Failed to load / parse countries.geojson.gz: \(error)")
            return nil
        }
        
        // TODO: See above maybe you can use a geojson library to make your life easier
        guard let geoJson = geoJson as? [String: Any],
              let features = geoJson["features"] as? [[String: Any]] else {
            return nil
        }
        
        var countryBorders: [String: [[CLLocationCoordinate2D]]] = [:]
        for feature in features {
            if let properties = feature["properties"] as? [String: Any],
               let countryISOA2 = properties["ISO_A2"] as? String,
               // let country_name = properties["ADMIN"] as? String,
               let geometry = feature["geometry"] as? [String: Any],
               let coordinates = geometry["coordinates"] as? [[[[Double]]]] {
                
                var borders = [[CLLocationCoordinate2D]]()
                
                for polygon in coordinates {
                    var borderCoordinates = [CLLocationCoordinate2D]()
                    for coordinateSet in polygon {
                        for coordinate in coordinateSet {
                            let lon = coordinate[0]
                            let lat = coordinate[1]
                            borderCoordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        }
                    }
                    borders.append(borderCoordinates)
                }
                
                countryBorders[countryISOA2] = borders
            }
        }
        return countryBorders
    }
    
    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371.00887714 // Mean earth radius in km, we just take this value as the truth. R_0 of the WGS 84.
        let dLat = (lat2 - lat1).degreesToRadians
        let dLon = (lon2 - lon1).degreesToRadians
        let a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1.degreesToRadians) * cos(lat2.degreesToRadians) *
        sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
    
    private func isCountryWithinDistance(start: CLLocationCoordinate2D, radius: Double, countryBorders: [String: [[CLLocationCoordinate2D]]]) -> [String] {
        var nearbyCountries = [String]()
        
        // TODO: See above maybe you can use a geojson library to improve the speed of this distance calculation.
        for (country, borders) in countryBorders {
            for border in borders {
                for borderCoordinate in border {
                    let distance = haversineDistance(lat1: start.latitude, lon1: start.longitude, lat2: borderCoordinate.latitude, lon2: borderCoordinate.longitude)
                    if distance <= radius {
                        nearbyCountries.append(country)
                        break
                    }
                }
            }
        }
        
        return nearbyCountries
    }
    
    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        guard let (latitude, longitude) = queryLatLong(queryCellId) else {
            return .finishEarly
        }
        
        let cc: String
        switch await getCountryCode(latitude: latitude, longitude: longitude) {
        case let .found(foundCC):
            cc = foundCC
        case .error:
            return .delay(seconds: 60)
        case .none:
            return .success()
        }
        
        guard let cellCc = OperatorDefinitions.shared.translate(country: queryCell.country, iso: true)?.uppercased() else {
            return .success()
        }
        
        // Checks wether the translated MCC is corresponds to the user's country code
        guard cellCc == cc else {
            return .fail()
        }
        
        guard let countryBorders = Self.countryBorders else {
            logger.warning("Skipping stage as borders failed to load")
            return .success()
        }
        
        guard let (distance, _, _) = PersistenceController.shared.calculateDistance(tweakCell: queryCellId) else {
            // If we can't get the distance, we delay the verification
            logger.warning("Can't calculate distance")
            return .success()
        }
        
        let startPoint = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let radius = distance.distance.degreesToRadians
        
        var nearbyCountries = isCountryWithinDistance(start: startPoint, radius: radius, countryBorders: countryBorders)
        nearbyCountries.append(cc)
        
        if nearbyCountries.contains(cellCc) {
            logger.info("GEO: Countries within \(radius) km: \(nearbyCountries)")
            return .success()
        } else {
            return .fail()
        }
    }
}

struct SNVerificationPipeline: VerificationPipeline {
    
    var id: Int16 = 2
    var name = "SnoopSnitch"
    var logger = pipelineLogger
    
    var after: (any VerificationPipeline)? = CGVerificationPipeline.instance
    var stages: [any VerificationStage] = [
        NoConnectionDummyStage(),
        No3GConnectionStage(),
        No2GConnectionStage(),
        CheckCorrectMCCStage(),
        CheckCorrectMNCStage(),
        CheckDistanceOfCell()
    ]
    
    static var instance = SNVerificationPipeline()
    
}
