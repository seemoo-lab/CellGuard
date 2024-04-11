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
}

enum AppModes: String, CaseIterable, Identifiable {
    // TODO: Change to automatic
    case jailbroken
    // TODO: Change to manual
    case nonJailbroken
    case analysis
    
    var id: Self { self }
    
    var description: String {
        switch self {
        case .analysis: return "Analysis"
        case .nonJailbroken: return "Non-Jailbroken"
        case .jailbroken: return "Jailbroken"
        }
    }
}

extension UserDefaults {
    
    func appMode() -> AppModes {
        let appModeString = UserDefaults.standard.string(forKey: UserDefaultsKeys.appMode.rawValue)
        guard let appModeString = appModeString else {
            return .jailbroken
        }
        
        guard let appMode = AppModes(rawValue: appModeString) else {
            return .jailbroken
        }
        
        return appMode
    }
    
}
