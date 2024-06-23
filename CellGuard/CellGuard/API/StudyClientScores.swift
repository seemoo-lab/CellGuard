//
//  StudyClientScores.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.06.24.
//

import Foundation
import CoreData

// Type alias so we can keep the code from the backend as it is
private typealias Content = Codable

private struct CreateWeeklyRateDTO: Content {
    var rateSuspicious: Float
    var rateUntrusted: Float
    var country: String
}

private struct CreateWeeklyRatesDTO: Content {
    var rates: [CreateWeeklyRateDTO]
}

extension StudyClient {
    
    func uploadWeeklyDetectionSummary(scoreIds: [NSManagedObjectID]) async throws {
        
        // Gathering all information for this chunk.
        // Usually we put all queries into Core Data / Queries, but we make an exception here as we don't want to expose all backend structs.
        let dtos = try persistence.performAndWait(name: "fetchContext", author: "uploadWeeklyScores") { context in
            return scoreIds.compactMap { (rateId) -> CreateWeeklyRateDTO? in
                // Get the score's object from the database
                guard let rate = context.object(with: rateId) as? StudyScore else {
                    return nil
                }
                
                return createDTO(fromRate: rate)
            }
        } ?? []
        
        if dtos.isEmpty {
            Self.logger.warning("No weekly detection scores to upload: \(scoreIds)")
            return
        }
        
        // Upload data
        let jsonData = try jsonEncoder.encode(dtos)
        try await upload(jsonData: jsonData, url: CellGuardURLs.apiCells, description: "weekly scores")
        
        // Store that we've successfully uploaded those weekly rates
        try persistence.saveStudyScoresUploadDate(scores: scoreIds, uploadDate: Date())
    }
    
    private func createDTO(fromRate rate: StudyScore) -> CreateWeeklyRateDTO {
        return CreateWeeklyRateDTO(
            rateSuspicious: Float(rate.rateSuspicious),
            rateUntrusted: Float(rate.rateUntrusted),
            country: rate.country ?? "n/a"
        )
    }
    
}
