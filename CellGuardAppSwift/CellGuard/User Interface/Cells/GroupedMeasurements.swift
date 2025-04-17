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

    let settings: CellListFilterSettings
    let measurements: [CellTweak]
    let openEnd: Bool
    let start: Date
    let end: Date
    let id: Int

    init(measurements: [CellTweak], openEnd: Bool, settings: CellListFilterSettings) throws {
        // We require that the list contains at least one element
        if measurements.isEmpty {
            throw GroupedMeasurementsError.emptyList
        }
        self.measurements = measurements
        self.openEnd = openEnd
        self.settings = settings

        // We assume the measurements are sorted in descending order based on their timestamp
        guard let end = measurements.first?.collected else {
            throw GroupedMeasurementsError.missingEndDate
        }
        guard let start = measurements.last?.collected else {
            throw GroupedMeasurementsError.missingStartDate
        }
        self.start = start
        self.end = end

        let stats = Self.countByStatus(measurements)

        // Use the list's hash value to identify the list.
        // See: https://stackoverflow.com/a/68068346
        var hash = measurements.hashValue
        // The measurement should also update if its number of cells in a category changes, so we must include them with the hashCode.
        // 31 is a prime and thus good for a hash distribution.
        // See: https://stackoverflow.com/a/3613423
        // See: https://www.baeldung.com/java-hashcode#standard-hashcode-implementations
        // We have to ignore the arithmetic overflow.
        // See: https://stackoverflow.com/a/35974079
        hash = 31 &* hash &+ (stats.pending ? 1 : 0)
        hash = 31 &* hash &+ Int(stats.score)
        hash = 31 &* hash &+ Int(stats.pointsMax)
        // Use the hash code as the list's id
        self.id = hash
    }

    func detailsPredicate() -> NSPredicate {
        return NSCompoundPredicate(
            andPredicateWithSubpredicates: settings.predicates(startDate: start, endDate: openEnd ? nil : end)
        )
    }

    static func countByStatus(_ measurements: any RandomAccessCollection<CellTweak>) -> (pending: Bool, score: Int16, pointsMax: Int16) {
        return countByStatus(measurements.compactMap { $0.primaryVerification })
    }

    private static func countByStatus(_ verificationStates: any RandomAccessCollection<VerificationState>) -> (pending: Bool, score: Int16, pointsMax: Int16) {
        var lowestScore: Int16?
        var pending = false

        for state in verificationStates {
            if !state.finished {
                pending = true
            } else {
                if let lowestScoreNN = lowestScore, state.score < lowestScoreNN {
                    lowestScore = state.score
                } else {
                    lowestScore = state.score
                }
            }
        }

        // Ignore the pending status if there is an anomalous or suspicious cell
        if let lowestScore = lowestScore, lowestScore < primaryVerificationPipeline.pointsSuspicious {
            pending = false
        }

        return (pending, lowestScore ?? primaryVerificationPipeline.pointsMax, primaryVerificationPipeline.pointsMax)
    }

}
