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
    case logArchiveSpeedup
    case study
    case activePipelines
    case basebandProfileInstall
    case basebandProfileRemoval
}

enum DataCollectionMode: String, CaseIterable, Identifiable {
    #if JAILBREAK
    case automatic
    #endif
    case manual
    case none
    
    var id: Self { self }
    
    var description: String {
        switch self {
        #if JAILBREAK
            // Jailbroken, i.e., import data via querying tweaks
        case .automatic: return "Automatic"
        #endif
            // Non-jailbroken, i.e., import data by reading sysdiagnosees
        case .manual: return "Manual"
            // Don't import / collect any data, including location, but allow to import CSV files
        case .none: return "None"
        }
    }
}

extension UserDefaults {
    
    func dataCollectionMode() -> DataCollectionMode {
        let appModeString = string(forKey: UserDefaultsKeys.appMode.rawValue)
        guard let appModeString = appModeString else {
            return .none
        }
        
        guard let appMode = DataCollectionMode(rawValue: appModeString) else {
            return .none
        }
        
        return appMode
    }
    
    func set(_ date: Date?, forKey key: String) {
        if let date = date {
            set(date.timeIntervalSince1970, forKey: key)
        } else {
            removeObject(forKey: key)
        }
    }
    
    func date(forKey key: String) -> Date? {
        let timeIntervalSince1970 = double(forKey: key)
        if timeIntervalSince1970 > 0 {
            return Date(timeIntervalSince1970: timeIntervalSince1970)
        } else {
            return nil
        }
    }
    
    func userEnabledVerificationPipelineIds() -> [Int16] {
        let primaryId = primaryVerificationPipeline.id
        
        // If none are set, just enable the primary pipeline
        guard let pipelineIds = array(forKey: UserDefaultsKeys.activePipelines.rawValue) as? [Int16] else {
            return [primaryId]
        }
        
        // Add primary pipeline if missing
        var localIds = pipelineIds
        if !localIds.contains(primaryId) {
            localIds.append(primaryId)
        }
        
        // Sort the pipelines by their id
        return localIds.sorted { $0 < $1 }
    }
    
    func userEnabledVerificationPipelines() -> [any VerificationPipeline] {
        // Map all pipeline ids to their pipeline
        return userEnabledVerificationPipelineIds().compactMap { pipelineId in
            activeVerificationPipelines.first { $0.id == pipelineId }
        }
    }
    
}
