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
    
    let measurements: [CellTweak]
    let openEnd: Bool
    let start: Date
    let end: Date
    let id: Int
    
    init(measurements: [CellTweak], openEnd: Bool) throws {
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
        
        let stats = Self.countByStatus(measurements: measurements)
        
        // Use the list's hash value to identify the list.
        // See: https://stackoverflow.com/a/68068346
        var hash = measurements.hashValue
        // The measurement should also update if its number of cells in a category changes, so we must include them with the hashCode.
        // 31 is a prime and thus good for a hash distribution.
        // See: https://stackoverflow.com/a/3613423
        // See: https://www.baeldung.com/java-hashcode#standard-hashcode-implementations
        // We have to ignore the arithmetic overflow.
        // See: https://stackoverflow.com/a/35974079
        hash = 31 &* hash &+ stats.pending
        hash = 31 &* hash &+ stats.untrusted
        hash = 31 &* hash &+ stats.suspicious
        hash = 31 &* hash &+ stats.trusted
        // Use the hash code as the list's id
        self.id = hash
    }
    
    static func countByStatus(measurements: any RandomAccessCollection<CellTweak>) -> (pending: Int, trusted: Int, suspicious: Int, untrusted: Int) {
        let verificationStates = measurements.compactMap { $0.primaryVerification }
        
        var pending = 0
        
        var untrusted = 0
        var suspicious = 0
        var trusted = 0
        
        for state in verificationStates {
            if state.finished {
                if state.score < primaryVerificationPipeline.pointsUntrusted {
                    untrusted += 1
                } else if state.score < primaryVerificationPipeline.pointsSuspicious {
                    suspicious += 1
                } else {
                    trusted += 1
                }
            } else {
                pending += 1
            }
        }
        
        return (pending, trusted, suspicious, untrusted)
    }
    
}
