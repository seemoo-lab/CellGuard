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

extension Double {
    var degrees_to_Radians: Double {
        return self * .pi / 180.0
    }
}

func getCountryCode(latitude: Double, longitude: Double, completion: @escaping (String) -> Void) {
    let location = CLLocation(latitude: latitude, longitude: longitude)
    
    let geocoder = CLGeocoder()
    geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
        if let error = error {
            completion("UNKNOWN")
            return
        }
        
        guard let placemark = placemarks?.first else {
            completion("UNKNOWN")
            return
        }
        
        if let isoCountryCode = placemark.isoCountryCode {
            completion(isoCountryCode)
        } else {
            completion("UNKNOWN")
        }
    }
}

// Synchronous wrapper
func getCountryCodeSync(latitude: Double, longitude: Double) -> String {
    let semaphore = DispatchSemaphore(value: 0)
    var result: String = "UNKNOWN"
    
    getCountryCode(latitude: latitude, longitude: longitude) { countryCode in
        result = countryCode
        semaphore.signal()
    }
    
    semaphore.wait()
    return result
}

func loadGeoJSON(from data: Data) -> [String: [[CLLocationCoordinate2D]]]? {
    do {
        if let geoJSON = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let features = geoJSON["features"] as? [[String: Any]] {
            
            var countryBorders: [String: [[CLLocationCoordinate2D]]] = [:]
            
            for feature in features {
                if let properties = feature["properties"] as? [String: Any],
                   let countryISOA2 = properties["ISO_A2"] as? String,
                   //let country_name = properties["ADMIN"] as? String,
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
    } catch {
        print("Error parsing GeoJSON: \(error)")
    }
    
    return nil
}

func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
    let R = 6371.00887714 // Mean earth radius in km, we just take this value as the truth. R_0 of the WGS 84.
    let dLat = (lat2 - lat1).degrees_to_Radians
    let dLon = (lon2 - lon1).degrees_to_Radians
    let a = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1.degrees_to_Radians) * cos(lat2.degrees_to_Radians) *
            sin(dLon / 2) * sin(dLon / 2)
    let c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return R * c
}

func isCountryWithinDistance(start: CLLocationCoordinate2D, radius: Double, countryBorders: [String: [[CLLocationCoordinate2D]]]) -> [String] {
    var nearbyCountries = [String]()
    
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
        if queryCell.technology == .UMTS {
            if let latitude = persistence.fetchCellAttribute(cell: queryCellId, extract: {$0.location?.latitude}) {
                if let longitude = persistence.fetchCellAttribute(cell: queryCellId, extract: {$0.location?.longitude}) {
                    let cc = getCountryCodeSync(latitude: latitude, longitude: longitude)
                    
                    switch cc {
                    case "DE", "NO", "LU", "CZ", "NL", "HU", "IT", "CY", "MT", "GR":
                        return .fail()
                    default:
                        return .success()
                    }
                } else { return .delay(seconds: 3) }
            } else { return .delay(seconds: 2) }
        }
        return .success()
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
        
        if queryCell.technology == .GSM {
            if let latitude = persistence.fetchCellAttribute(cell: queryCellId, extract: {$0.location?.latitude}) {
                if let longitude = persistence.fetchCellAttribute(cell: queryCellId, extract: {$0.location?.longitude}) {
                    let cc = getCountryCodeSync(latitude: latitude, longitude: longitude)
                    
                    switch cc {
                    // ISO 3166 codes for countries, that reportedly, don't use GSM/2G anymore.
                    case "CH", "AU", "BH", "BN", "CN", "CO", "HK", "JP", "MX", "SG", "ZA", "KR", "TW", "AE", "US":
                        return .fail()
                    default:
                        return .success()
                    }
                } else { return .delay(seconds: 3) }
            } else { return .delay(seconds: 2) }
        }
        
        return .success()
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
        if let latitude = persistence.fetchCellAttribute(cell: queryCellId, extract: {$0.location?.latitude}) {
            if let longitude = persistence.fetchCellAttribute(cell: queryCellId, extract: {$0.location?.longitude}) {
                let cc = getCountryCodeSync(latitude: latitude, longitude: longitude)
                
                /// Checks wether the translated MCC is corrosponend to the users country code
                if OperatorDefinitions.shared.translate(country: queryCell.country, iso: true)!.uppercased() == cc.uppercased() {
                    return .success()
                } else { return .fail() }
            } else { return .delay(seconds: 3) }
        } else { return .delay(seconds: 2) }
    }
}

private struct CheckCorrectMNCStage: VerificationStage {
    
    var id: Int16 = 5
    var name: String = "Correct MNC"
    var description: String = "Checks wether the MNC is corresponded to the correct operator in the correct country."
    var points: Int16 = 1
    var waitForPackets: Bool = false
    
    private let persistence = PersistenceController.shared
        
    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        if let latitude = persistence.fetchCellAttribute(cell: queryCellId, extract: {$0.location?.latitude}) {
            if let longitude = persistence.fetchCellAttribute(cell: queryCellId, extract: {$0.location?.longitude}) {
                let cc = getCountryCodeSync(latitude: latitude, longitude: longitude)
                
                if OperatorDefinitions.shared.translate(country: queryCell.country, network: queryCell.network, iso: true).0?.uppercased() == cc.uppercased() {
                    return .success()
                } else { return .fail() }
            } else { return .delay(seconds: 3) }
        } else { return .delay(seconds: 2) }
    }
}

private struct CheckDistanceOfCell: VerificationStage {
    
    var id: Int16 = 6
    var name: String = "Correct Distance of Cell"
    var description: String = "Checks wether it is possible, that a user is near a country boarder, thus connecting to a different MCC."
    var points: Int16 = 1
    var waitForPackets: Bool = false
    
    private let persistence = PersistenceController.shared
        
    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        if let latitude = persistence.fetchCellAttribute(cell: queryCellId, extract: {$0.location?.latitude}) {
            if let longitude = persistence.fetchCellAttribute(cell: queryCellId, extract: {$0.location?.longitude}) {
                let cc = getCountryCodeSync(latitude: latitude, longitude: longitude).uppercased()
                
                let cell_cc = OperatorDefinitions.shared.translate(country: queryCell.country, iso: true)!.uppercased()
                
                /// Checks wether the translated MCC is corrosponend to the users country code
                if cell_cc == cc {
                    if let path = Bundle.main.path(forResource: "countries", ofType: "geojson"),
                       let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                       let countryBorders = loadGeoJSON(from: data) {
                        
                        guard let (distance, _, _) = persistence.calculateDistance(tweakCell: queryCellId) else {
                            // If we can't get the distance, we delay the verification
                            logger.warning("Can't calculate distance")
                            return .delay(seconds: 60)
                        }
                        
                        let startPoint = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                        let radius = distance.distance.degrees_to_Radians
                        
                        
                        var nearbyCountries = isCountryWithinDistance(start: startPoint, radius: radius, countryBorders: countryBorders)
                        nearbyCountries.append(cc)
                        
                        if nearbyCountries.contains(cell_cc) {
                            logger.info("GEO: Countries within \(radius) km: \(nearbyCountries)")
                            return .success()
                        } else {return .fail()}
                        
                        
                    } else {
                        logger.warning("GEO: Failed to load GeoJSON data.")
                    }
                    
                    return .success()
                } else { return .fail() }
            } else { return .delay(seconds: 3) }
        } else { return .delay(seconds: 2) }
    }
}

struct SNVerificationPipeline: VerificationPipeline {
    
    var logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: SNVerificationPipeline.self)
    )
    
    var id: Int16 = 2
    var name = "SnoopSnitch"
    
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
