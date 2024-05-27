//
//  SNVerificationPipeline.swift
//  CellGuard
//
//  Created by Lukas Arnold on 06.05.24.
//

import Foundation
import CoreData
import OSLog
import CoreLocation

func getCountryCode(latitude: Double, longitude: Double, completion: @escaping (String?) -> Void) {
    let location = CLLocation(latitude: latitude, longitude: longitude)
    
    let geocoder = CLGeocoder()
    geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
        if let error = error {
            print("Reverse geocode failed with error: \(error.localizedDescription)")
            completion(nil)
            return
        }
        
        guard let placemark = placemarks?.first else {
            print("No placemark found")
            completion(nil)
            return
        }
        
        if let isoCountryCode = placemark.isoCountryCode {
            completion(isoCountryCode)
        } else {
            print("Country code not found")
            completion(nil)
        }
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
    
    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        if queryCell.technology == .UMTS {
            var cc: String = ""
            getCountryCode(latitude: queryCell.location?.latitude ?? 0.0, longitude: queryCell.location?.longitude ?? 0.0) { countryCode in cc = countryCode ?? ""}
            
            switch cc {
            case "DE", "NO", "LU", "CZ", "NL", "HU", "IT", "CY", "MT", "GR":
                return .fail()
            default:
                return .success()
            }
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
    
    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        if queryCell.technology == .GSM {
            var cc: String = ""
            getCountryCode(latitude: queryCell.location?.latitude ?? 0.0, longitude: queryCell.location?.longitude ?? 0.0) { countryCode in cc = countryCode ?? ""}
            
            switch cc {
            // ISO 3166 codes for countries, that reportedly, don't use GSM/2G anymore.
            case "CH", "AU", "BH", "BN", "CN", "CO", "HK", "JP", "MX", "SG", "ZA", "KR", "TW", "AE", "US":
                return .fail()
            default:
                return .success()
            }
        }
        
        return .success()
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
        No2GConnectionStage()
    ]
    
    static var instance = SNVerificationPipeline()
    
}
