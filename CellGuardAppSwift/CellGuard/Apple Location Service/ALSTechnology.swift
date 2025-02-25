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

enum ALSTechnologyVersion: String {
    case cdma1x
    case cdmaEvdo
    case umts
    case tdscdma
    case gsm
    case lteV1
    case lteV2
    case lteV3
    case lteV4
    case lte
    case lteV1T
    case lteR15
    case nr
    case nrV2
    case nrV3
}
