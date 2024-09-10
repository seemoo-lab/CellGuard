import Foundation
import CoreData
import OSLog
import Dispatch
import CoreLocation
import CoreTelephony

// Logger instance for the pipeline
private let pipelineLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: String(describing: SNVerificationPipeline.self)
)

// Extension for converting degrees to radians
extension Double {
    var degreesToRadians: Double { self * .pi / 180.0 }
}

// Enum to handle country code result
private enum CountryCodeResult {
    case found(String)
    case none
    case error
}

private struct CompareableCLLocation: Hashable {
    let latitude: Double
    let longitude: Double
    
    func toCL() -> CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

// Cache for the country code to prevent unnecessary requests -> speed up + less rate-limit issues
private var countryCodeCache: [CompareableCLLocation: String] = [:]

private func getCountryCode(latitude: Double, longitude: Double) async -> CountryCodeResult {
    let location = CompareableCLLocation(latitude: latitude, longitude: longitude)
    
    if let cachedResult = countryCodeCache[location] {
        return .found(cachedResult)
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
        if let isoCountryCode = placemarks.first?.isoCountryCode {
            countryCodeCache[location] = isoCountryCode
            return .found(isoCountryCode)
        }
        return .none
    } catch {
        pipelineLogger.warning("Failed to get country code for (\(latitude), \(longitude)): \(error)")
        return .error
    }
}

// Function to query latitude and longitude for a given cell ID
private func queryLatLong(_ queryCellId: NSManagedObjectID) -> (Double, Double)? {
    PersistenceController.shared.fetchCellAttribute(cell: queryCellId) { cell -> (Double, Double)? in
        guard let location = cell.location else { return nil }
        return (location.latitude, location.longitude)
    }
}

private struct NoConnectionDummyStage: VerificationStage {
    var id: Int16 = 1
    var name = "No Connection Defaults"
    var description = "Skips default measurements present when there's no connection."
    var points: Int16 = 0
    var waitForPackets: Bool = false

    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        if queryCell.technology == .UMTS && queryCell.cell == 0xFFFFFFFF {
            return .finishEarly
        }
        return .success()
    }
}

private struct No3GConnectionStage: VerificationStage {
    var id: Int16 = 2
    var name = "No 3G Connection"
    var description = "Checks if the phone is connected to a 3G cell in a 'No-3G-Country'."
    var points: Int16 = 1
    var waitForPackets: Bool = false
    
    private let prohibited3GCountries: Set<String> = ["DE", "NO", "LU", "CZ", "NL", "HU", "IT", "CY", "MT", "GR"]

    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        guard queryCell.technology == .UMTS else { return .success() }
        
        guard let (latitude, longitude) = queryLatLong(queryCellId) else { return .finishEarly }

        switch await getCountryCode(latitude: latitude, longitude: longitude) {
        case let .found(countryCode):
            return prohibited3GCountries.contains(countryCode) ? .fail() : .success()
        case .error:
            return .delay(seconds: 60)
        case .none:
            return .success()
        }
    }
}

private struct No2GConnectionStage: VerificationStage {
    var id: Int16 = 3
    var name = "No 2G Connection"
    var description = "Checks if the phone is connected to a 2G cell in a 'No-2G-Country'."
    var points: Int16 = 1
    var waitForPackets: Bool = false
    
    private let prohibited2GCountries: Set<String> = ["CH", "AU", "BH", "BN", "CN", "CO", "HK", "JP", "MX", "SG", "ZA", "KR", "TW", "AE", "US"]

    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        guard queryCell.technology == .GSM else { return .success() }
        
        guard let (latitude, longitude) = queryLatLong(queryCellId) else { return .success() }

        switch await getCountryCode(latitude: latitude, longitude: longitude) {
        case let .found(countryCode):
            return prohibited2GCountries.contains(countryCode) ? .fail() : .success()
        case .error:
            return .delay(seconds: 60)
        case .none:
            return .success()
        }
    }
}

private struct CheckCorrectMCCStage: VerificationStage {
    var id: Int16 = 4
    var name = "Correct MCC"
    var description = "Checks if the MCC corresponds to the correct country."
    var points: Int16 = 1
    var waitForPackets: Bool = false

    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        guard let (latitude, longitude) = queryLatLong(queryCellId) else { return .success() }

        switch await getCountryCode(latitude: latitude, longitude: longitude) {
        case let .found(countryCode):
            let operatorCountry = OperatorDefinitions.shared.translate(country: queryCell.country, iso: true)
            guard let operatorCountry = operatorCountry else { return .success() }

            return operatorCountry.uppercased() == countryCode.uppercased() ? .success() : .fail()
        case .error:
            return .delay(seconds: 60)
        case .none:
            return .success()
        }
    }
}

private struct CheckCorrectMNCStage: VerificationStage {
    var id: Int16 = 5
    var name = "Correct MNC"
    var description = "Checks if the MNC corresponds to the correct operator in the correct country."
    var points: Int16 = 1
    var waitForPackets: Bool = false

    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        guard let (latitude, longitude) = queryLatLong(queryCellId) else { return .success() }

        switch await getCountryCode(latitude: latitude, longitude: longitude) {
        case let .found(countryCode):
            let (operatorCountry, _) = OperatorDefinitions.shared.translate(country: queryCell.country, network: queryCell.network, iso: true)
            guard let operatorCountry = operatorCountry else { return .success() }

            return operatorCountry.uppercased() == countryCode.uppercased() ? .success() : .fail()
        case .error:
            return .delay(seconds: 60)
        case .none:
            return .success()
        }
    }
}

private struct CheckDistanceOfCell: VerificationStage {
    var id: Int16 = 6
    var name = "Correct Distance of Cell"
    var description = "Checks if the cell is near the country border, indicating a possible MCC mismatch."
    var points: Int16 = 1
    var waitForPackets: Bool = false
    
    private static let countryBorders: [String: [[CLLocationCoordinate2D]]]? = loadGeoJson()
    
    private let persistence = PersistenceController.shared

    // Loads GeoJSON data for country borders
    private static func loadGeoJson() -> [String: [[CLLocationCoordinate2D]]]? {
        guard let path = Bundle.main.path(forResource: "countries", ofType: "geojson") else {
            pipelineLogger.warning("Can't find GeoJSON file")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            guard let geoJson = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            
            var borders: [String: [[CLLocationCoordinate2D]]] = [:]
            if let features = geoJson["features"] as? [[String: Any]] {
                for feature in features {
                    if let properties = feature["properties"] as? [String: Any],
                       let geometry = feature["geometry"] as? [String: Any],
                       let isoCode = properties["ISO_A2"] as? String,
                       let polygons = geometry["coordinates"] as? [[[Double]]] {
                        
                        borders[isoCode] = polygons.map { polygon in
                            polygon.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
                        }
                    }
                }
            }
            return borders
        } catch {
            pipelineLogger.error("Error loading GeoJSON: \(error)")
            return nil
        }
    }

    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        guard let (latitude, longitude) = queryLatLong(queryCellId) else { return .success() }
        
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        switch await getCountryCode(latitude: latitude, longitude: longitude) {
        case let .found(countryCode):
            guard let borderCoordinates = CheckDistanceOfCell.countryBorders?[countryCode] else { return .success() }
            
            guard let (distanceCell, _, _) = persistence.calculateDistance(tweakCell: queryCellId) else {
                        logger.warning("Can't calculate distance")
                        return .success()
            }


            for polygon in borderCoordinates {
                if let distance = polygon.map({ CLLocation(latitude: $0.latitude, longitude: $0.longitude) }).map({ $0.distance(from: location) }).min(), distance < distanceCell.distance {
                    logger.warning("Cell is too close to the border of country \(countryCode) with distance: \(distance)")
                    return .fail()
                }
            }
            
            return .success()
        case .error:
            return .delay(seconds: 60)
        case .none:
            return .success()
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
