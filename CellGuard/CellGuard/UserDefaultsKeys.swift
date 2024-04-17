//
//  UserDefaultsKeys.swift
//  CellGuard
//
//  Created by Lukas Arnold on 16.01.23.
//

import Foundation

enum UserDefaultsKeys: String {
    case introductionShown
    case packetRetention
    case locationRetention
    case showTrackingMarker
    case lastExportDate
    case appMode
    case highVolumeSpeedup
}

enum DataCollectionMode: String, CaseIterable, Identifiable {
    case automatic
    case manual
    case none
    
    var id: Self { self }
    
    var description: String {
        switch self {
            // Jailbroken, i.e., import data via querying tweaks
        case .automatic: return "Automatic"
            // Non-jailbroken, i.e., import data by reading sysdiagnosees
        case .manual: return "Manual"
            // Don't import / collect any data, including location, but allow to import CSV files
        case .none: return "None"
        }
    }
}

extension UserDefaults {
    
    func dataCollectionMode() -> DataCollectionMode {
        let appModeString = UserDefaults.standard.string(forKey: UserDefaultsKeys.appMode.rawValue)
        guard let appModeString = appModeString else {
            return .none
        }
        
        guard let appMode = DataCollectionMode(rawValue: appModeString) else {
            return .none
        }
        
        return appMode
    }
    
}
