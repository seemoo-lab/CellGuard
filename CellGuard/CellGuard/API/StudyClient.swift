//
//  StudyClient.swift
//  CellGuard
//
//  Created by Lukas Arnold on 13.05.24.
//

import CoreData
import Foundation
import OSLog

// Type alias so we can keep the code from the backend as it is
private typealias Content = Codable

// Definitions from the backend
enum FeedbackRiskLevel: String, Codable, CaseIterable {
    case untrusted, suspicious, trusted
}

private enum CellTechnology: String, Codable, CaseIterable {
    case gsm, scdma, cdma, umts, lte, nr
}

private enum BasebandPacketProtocol: String, Codable, CaseIterable {
    case qmi, ari
}

private enum BasebandPacketDirection: String, Codable, CaseIterable {
    case ingoing, outgoing
}

private struct CreateUserFeedbackDTO: Content {
    var suggestedLevel: FeedbackRiskLevel
    var comment: String
}

private struct CreateCellPacketDTO: Content {
    var proto: BasebandPacketProtocol
    var direction: BasebandPacketDirection
    var data: Data
    var collectedAt: Date
}

private struct CreateCellScoreDTO: Content {
    var pipeline: UInt16
    var stage: UInt16
    var score: UInt8
    var maximum: UInt8
}

private struct CreateCellDTO: Content {
    var technology: CellTechnology
    var country: UInt16
    var network: UInt16
    var area: UInt32
    var cellId: UInt64
    var cellIdPhysical: UInt32
    var frequency: UInt32
    var bandwidth: UInt32
    var band: UInt32
    var userLatitude: Double
    var userLongitude: Double
    var collectedAt: Date?
    var json: String?
    
    var feedback: CreateUserFeedbackDTO?
    var packets: [CreateCellPacketDTO]
    var scores: [CreateCellScoreDTO]
}

// Definitions for the app
struct CellIdWithFeedback {
    let cell: NSManagedObjectID
    let feedbackComment: String?
    let feedbackLevel: FeedbackRiskLevel?
}

enum StudyClientError: Error {
    case uploadErrorLocal(Error)
    case uploadErrorExternal(URLResponse?)
}

// The client for the backend
struct StudyClient {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: StudyCell.self)
    )
    
    private let persistence = PersistenceController()
    private let packetFilter = StudyPacketFilter()
    private let jsonEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()
    
    func uploadCellSamples(cells: [CellIdWithFeedback]) async throws {
        // Chunking the samples into blocks of 10 as this is the maximum limit for one API request.
        for (index, cellsChunk) in cells.chunked(into: 10).enumerated() {
            Self.logger.debug("Preparing chunk \(index) of \(cellsChunk.count) cell(s) for upload")
            
            // Gathering all information for this chunk.
            // Usually we put all queries into Core Data / Queries, but we make an exception here as we don't want to expose all backend structs.
            let dtos = try persistence.performAndWait(name: "fetchContext", author: "uploadCellSamples") { context in
                return try cellsChunk.compactMap { (cellIdWithFeedback) -> CreateCellDTO? in
                    // Get the cell's object from the database
                    guard let cell = context.object(with: cellIdWithFeedback.cell) as? CellTweak else {
                        return nil
                    }
                    
                    // The cell must contain the collected timestamp
                    guard let collected = cell.collected else {
                        return nil
                    }
                    
                    // We collect all packets 15s before and after the collection of the cell (AS IS APPROVED BY ETHICS BOARD)
                    let packetPredicate = NSPredicate(
                        format: "collected > %@ and collected < %@",
                        collected.addingTimeInterval(-15) as NSDate,
                        collected.addingTimeInterval(15) as NSDate
                    )
                    let packetSortDescriptor = NSSortDescriptor(key: "collected", ascending: true)
                    
                    let qmiPacketFetchRequest = PacketQMI.fetchRequest()
                    qmiPacketFetchRequest.predicate = packetPredicate
                    qmiPacketFetchRequest.sortDescriptors = [packetSortDescriptor]
                    
                    let ariPacketFetchRequest = PacketARI.fetchRequest()
                    ariPacketFetchRequest.predicate = packetPredicate
                    ariPacketFetchRequest.sortDescriptors = [packetSortDescriptor]
                    
                    // Fetch and filter the packets to remove personal information (AS IS APPROVED BY ETHICS BOARD)
                    let qmiPackets = (try qmiPacketFetchRequest.execute()).filter(packetFilter.filter)
                    let ariPackets = (try ariPacketFetchRequest.execute()).filter(packetFilter.filter)
                    
                    return createDTO(fromCell: cell, packets: qmiPackets + ariPackets, feedback: cellIdWithFeedback)
                }
            }
            
            
            // Encoding the data to JSON
            guard let dtos = dtos else {
                Self.logger.warning("Nil chunk \(index)")
                continue
            }
            
            let jsonData = try jsonEncoder.encode(dtos)
            
            // Sending the data to our backend
            // See: https://developer.apple.com/documentation/foundation/url_loading_system/uploading_data_to_a_website
            Self.logger.debug("Uploading chunk \(index) to \(CellGuardURLs.apiCells)")
            
            var request = URLRequest(url: CellGuardURLs.apiCells)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(), any Error>) in
                URLSession.shared.uploadTask(with: request, from: jsonData) { data, response, error in
                    if let error = error {
                        Self.logger.debug("Error while uploading chunk \(index): \(error)")
                        continuation.resume(throwing: StudyClientError.uploadErrorLocal(error))
                        return
                    }
                    guard let response = response as? HTTPURLResponse, response.statusCode == 201 else {
                        Self.logger.debug("Server error while uploading chunk \(index): \(response)")
                        continuation.resume(throwing: StudyClientError.uploadErrorExternal(response))
                        return
                    }
                    
                    Self.logger.debug("Successfully uploaded chunk \(index): \(response)")
                    continuation.resume()
                    return
                }
            }
            
            // Store that we've successfully uploaded those cells
            try persistence.saveStudyUploadDate(cells: cellsChunk.map { $0.cell }, uploadDate: Date())
        }
    }
    
    /// Converts a CellTweak to a CreateCellDTO.
    /// Only call this method from within  the Core Data context.
    private func createDTO(fromCell cell: CellTweak, packets: [any Packet], feedback: CellIdWithFeedback) -> CreateCellDTO {
        // Map each packet to this DTO
        let packets = packets.compactMap { createDTO(fromPacket: $0) }
        
        // Get all VerificationLogs for each pipeline and convert each one to its DTO
        let scores = cell.verifications?
            .compactMap { $0 as? VerificationState }
            .flatMap { state in
                state.logs?
                    .compactMap { $0 as? VerificationLog }
                    .map { createDTO(fromVerificationLog: $0) } ?? []
            } ?? []
        
        // Return the combined cell DTO
        return CreateCellDTO(
            technology: CellTechnology(rawValue: cell.technology ?? "") ?? .cdma,
            country: UInt16(cell.country),
            network: UInt16(cell.network),
            area: UInt32(cell.area),
            cellId: UInt64(cell.cell),
            cellIdPhysical: UInt32(cell.physicalCell),
            frequency: UInt32(cell.frequency),
            bandwidth: UInt32(cell.bandwidth),
            band: UInt32(cell.band),
            
            // Truncates the latitude & longitude to decimal places, resulting in an accuracy between 0.435 km and 1.11 km
            // See: https://en.wikipedia.org/wiki/Decimal_degrees
            userLatitude: cell.location?.latitude.truncate(places: 2) ?? 0,
            userLongitude: cell.location?.longitude.truncate(places: 2) ?? 0,
            
            collectedAt: cell.collected,
            json: cell.json,
            
            feedback: createDTO(fromFeedback: feedback),
            packets: packets,
            scores: scores
        )
    }
    
    private func createDTO(fromPacket packet: any Packet) -> CreateCellPacketDTO? {
        guard let directionString = packet.direction,
              let data = packet.data,
              let collected = packet.collected else {
            Self.logger.warning("Packet misses ones if its property: \(packet.description)")
            return nil
        }
        
        let proto: BasebandPacketProtocol
        switch CPTProtocol(rawValue: packet.proto) {
        case .ari:
            proto = .ari
        case .qmi:
            proto = .qmi
        default:
            Self.logger.warning("Unknown proto: \(packet.proto)")
            return nil
        }
        
        let direction: BasebandPacketDirection
        switch CPTDirection(rawValue: directionString) {
        case .ingoing:
            direction = .ingoing
        case .outgoing:
            direction = .outgoing
        default:
            Self.logger.warning("Unknown packet direction: \(directionString)")
            return nil
        }
        
        return CreateCellPacketDTO(
            proto: proto,
            direction: direction,
            data: data,
            collectedAt: collected
        )
    }
    
    private func createDTO(fromVerificationLog log: VerificationLog) -> CreateCellScoreDTO {
        return CreateCellScoreDTO(
            pipeline: UInt16(log.pipeline?.pipeline ?? 0),
            stage: UInt16(log.stageId),
            score: UInt8(log.pointsAwarded),
            maximum: UInt8(log.pointsMax)
        )
    }
    
    private func createDTO(fromFeedback feedback: CellIdWithFeedback) -> CreateUserFeedbackDTO? {
        guard let feedbackLevel = feedback.feedbackLevel, 
                let feedbackComment = feedback.feedbackComment else {
            return nil
        }
        
        return CreateUserFeedbackDTO(
            suggestedLevel: feedbackLevel,
            comment: feedbackComment
        )
    }
    
    func uploadWeeklyDetectionSummary() async throws {
        // TODO: Implement
    }
    
}
