//
//  ALSTechnology.swift
//  CellGuard
//
//  Created by Lukas Arnold on 25.01.23.
//

import Foundation
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: String(describing: ALSClient.self)
)

enum ALSTechnology: String, CaseIterable, Identifiable {
    case GSM
    case SCDMA
    case CDMA
    case UMTS
    case LTE
    case NR
    
    public static func from(cctTechnology: String) -> ALSTechnology {
        guard let alsTechnology = ALSTechnology(rawValue: cctTechnology) else {
            logger.warning("Unable to find the according ALS technology for '\(cctTechnology)'")
            return .LTE
        }
            
        return alsTechnology
    }
    
    var id: Self { self }
}
