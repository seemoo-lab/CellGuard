//
//  GroupedMeasurements.swift
//  CellGuard
//
//  Created by Lukas Arnold on 21.07.23.
//

import Foundation
import SwiftUI

enum GroupedMeasurementsError: Error {
    case emptyList
    case missingStartDate
    case missingEndDate
}

struct GroupedMeasurements: Identifiable {
    
    let measurements: [TweakCell]
    let openEnd: Bool
    let start: Date
    let end: Date
    let id: Int
    
    init(measurements: [TweakCell], openEnd: Bool) throws {
        // We require that the list contains at least one element
        if measurements.isEmpty {
            throw GroupedMeasurementsError.emptyList
        }
        self.measurements = measurements
        self.openEnd = openEnd
        
        // We assume the measurements are sorted in descending order based on their timestamp
        guard let end = measurements.first?.collected else {
            throw GroupedMeasurementsError.missingEndDate
        }
        guard let start = measurements.last?.collected else {
            throw GroupedMeasurementsError.missingStartDate
        }
        self.start = start
        self.end = end
        
        // Use the list's hash value to identify the list
        // See: https://stackoverflow.com/a/68068346
        self.id = measurements.hashValue
    }
    
    static func countByStatus(measurements: any RandomAccessCollection<TweakCell>) -> (pending: Int, trusted: Int, suspicious: Int, untrusted: Int) {
        let pendingCount = measurements.filter { $0.status != CellStatus.verified.rawValue }.count
        
        let verified = measurements.filter { $0.status == CellStatus.verified.rawValue }
        let trustedCount = verified.filter { $0.score >= CellVerifier.pointsSuspiciousThreshold }.count
        let suspiciousCount = verified.filter { CellVerifier.pointsUntrustedThreshold <= $0.score && $0.score < CellVerifier.pointsSuspiciousThreshold }.count
        let untrustedCount = verified.filter { $0.score < CellVerifier.pointsUntrustedThreshold }.count
        
        return (pendingCount, trustedCount, suspiciousCount, untrustedCount)
    }
    
}
