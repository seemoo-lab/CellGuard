//
//  ALSVerifier.swift
//  CellGuard
//
//  Created by Lukas Arnold on 18.01.23.
//

import Foundation
import CoreData
import OSLog

enum CellVerifierError: Error {
    case fetchCellToVerify(Error)
    case invalidCellStatus
    case verifiedCellFetched
    case fetchCellsFromALS(Error)
    case importALSCells(Error)
    case fetchPackets(Error)
}

private enum VerificationStageResult {
    case delay(seconds: Int)
    case next(status: CellStatus, points: Int)
    
}

struct CellVerifier {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CellVerifier.self)
    )
    
    static func verificationLoop() async {
        let verifier = CellVerifier()
        
        while (true) {
            // Don't verify cells while an import process is active
            if PersistenceImporter.importActive {
                // Sleep for one second
                try? await Task.sleep(nanoseconds: NSEC_PER_SEC)
            }
            
            // Timeout for async task: https://stackoverflow.com/a/75039407
            let verifyTask = Task {
                let taskResult = try await verifier.verifyFirst()
                // Without checkCancellation, verifyFirst() would keep going until infinity
                try Task.checkCancellation()
                // Sleep 50ms after a cell verification
                try await Task.sleep(nanoseconds: 50 * NSEC_PER_MSEC)
                return taskResult
            }
            
            // Set a timeout of 10s for each individual cell verification
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: 10 * NSEC_PER_SEC)
                verifyTask.cancel()
                Self.logger.warning("Cell verification timed out after 10s")
            }
            
            do {
                // Wait for the value
                let result = try await verifyTask.value
                // Cancel the timeout task if we've got the value before the timeout
                timeoutTask.cancel()
                // If there was no cell to verify, we sleep for 500ms
                if !result {
                    try? await Task.sleep(nanoseconds: 500 * NSEC_PER_MSEC)
                }
            } catch {
                Self.logger.warning("Cell verification resulted in an error: \(error)")
            }
        }
    }
    
    public static let pointsSuspiciousThreshold = 100
    public static let pointsUntrustedThreshold = 50
    
    private let pointsALS = 40
    private let pointsLocation = 20
    private let pointsPacket = 40
    
    private let persistence = PersistenceController.shared
    private let alsClient = ALSClient()
    
    func verifyFirst() async throws -> Bool {
        let queryCell: (NSManagedObjectID, ALSQueryCell, CellStatus?)?
        do {
            queryCell = try persistence.fetchLatestUnverifiedTweakCells(count: 1)
        } catch {
            throw CellVerifierError.fetchCellToVerify(error)
        }
        
        // Check if there is a cell to verify
        guard let (queryCellID, queryCell, queryCellStatus) = queryCell else {
            // There is currently no cell to verify
            return false
        }
        
        // Check if the cell status was parsed successfully
        guard var queryCellStatus = queryCellStatus else {
            throw CellVerifierError.invalidCellStatus
        }
        
        Self.logger.debug("Verifying cell \(queryCellID) with status \(queryCellStatus.rawValue): \(queryCell)")
        // Continue with the correct verification stage
        while (queryCellStatus != .verified) {
            // Run the verification stage for the cell's current state
            let result = try await verifyStage(status: queryCellStatus, queryCell: queryCell, queryCellID: queryCellID)
            
            // Based on the stage's result, we choose our course of action
            switch (result) {
                
            case let .next(nextStatus, points):
                // We store the resulting status and award the points, then the while-loop continues
                try persistence.storeCellStatus(cellId: queryCellID, status: nextStatus, addToScore: Int16(points))
                queryCellStatus = nextStatus
                
            case let .delay(delay):
                // We store the delay in the database and stop the verification loop
                try persistence.storeVerificationDelay(cellId: queryCellID, seconds: delay)
                break
            }
        }
        
        // We've verified a cell, so return true
        return true
    }
    
    private func verifyStage(status: CellStatus, queryCell: ALSQueryCell, queryCellID: NSManagedObjectID) async throws -> VerificationStageResult {
        switch (status) {
        case .imported:
            return try await verifyUsingALS(queryCell: queryCell, queryCellID: queryCellID)
        case .processedCell:
            return try await verifyDistance(queryCell: queryCell, queryCellID: queryCellID)
        case .processedLocation:
            return try await verifyPacket(queryCell: queryCell, queryCellID: queryCellID)
        case .verified:
            throw CellVerifierError.verifiedCellFetched
        }
    }
    
    private func verifyUsingALS(queryCell: ALSQueryCell, queryCellID: NSManagedObjectID) async throws -> VerificationStageResult {
        // Try to find the corresponding ALS cell in our database
        if let existing = try? persistence.assignExistingALSIfPossible(to: queryCellID), existing {
            Self.logger.info("ALS verification using the local database successful: \(queryCell)")
            return .next(status: .processedCell, points: pointsALS)
        }
        
        // If we can't find the cell in our database, we'll query ALS (and return to this thread)
        Self.logger.info("Requesting tweak cell from the remote ALS database: \(queryCell)")
        let alsCells: [ALSQueryCell]
        do {
            alsCells = try await alsClient.requestCells(origin: queryCell)
        } catch {
            throw CellVerifierError.fetchCellsFromALS(error)
        }
        Self.logger.debug("Received \(alsCells.count) cells from ALS")
        
        // Remove query cells with are only are rough approximation
        let preciseAlsCells = alsCells.filter { $0.hasCellId() }
        
        // Check if the resulting ALS cell is valid
        if !(preciseAlsCells.first?.isValid() ?? false) {
            Self.logger.info("ALS Verification failed as the first cell is not valid (0/40): \(queryCell)")
            // If not, do not add any points to it and continue with the packet verification
            return .next(status: .processedLocation, points: 0)
        }
        
        // If the cell is valid, import all cells of the ALS response
        do {
            try persistence.importALSCells(from: alsCells, source: queryCellID)
        } catch {
            throw CellVerifierError.importALSCells(error)
        }
        
        // Award the points based on the distance
        Self.logger.info("ALS verification successful (\(pointsALS)/\(pointsALS)): \(queryCell)")
        return .next(status: .processedCell, points: pointsALS)
    }
    
    private func verifyDistance(queryCell: ALSQueryCell, queryCellID: NSManagedObjectID) async throws -> VerificationStageResult {
        // Try to assign a location to the cell
        let (foundLocation, cellCollected) = try persistence.assignLocation(to: queryCellID)
        if !foundLocation {
            // We've missing a location for the cell, so ...
            if (cellCollected ?? Date.distantPast) < Date().addingTimeInterval(-5 * 60) {
                // If the cell is older than five minutes, we assume that we won't get the location data and just mark the location as checked
                Self.logger.info("No location found for cell (\(pointsLocation)/\(pointsLocation)): \(queryCell)")
                return .next(status: .processedLocation, points: pointsLocation)
            } else {
                // If the cell is younger than five minutes, we retry after 30s
                return .delay(seconds: 30)
            }
        }
        
        // Calculate the distance between the location assigned to the tweak cells & the ALS cell
        guard let distance = persistence.calculateDistance(tweakCell: queryCellID) else {
            // If we can't get the distance, we delay the verification
            Self.logger.warning("Can't calculate distance for cell \(queryCellID)")
            return .delay(seconds: 60)
        }
        
        // The score is a percentage of how likely the cell is evil, so we calculate an inverse of that and multiple it by the points
        let distancePoints = Int(Double(pointsLocation) * (1.0 - distance.score()))
        Self.logger.info("Location verified for cell (\(distancePoints)/\(pointsLocation)): \(queryCell)")
        return .next(status: .processedLocation, points: distancePoints)
    }
    
    private func verifyPacket(queryCell: ALSQueryCell, queryCellID: NSManagedObjectID) async throws -> VerificationStageResult {
        // Delay the verification 20s if no newer cell exists, i.e., we are still connected to this cell
        guard let (start, end, _) = try persistence.fetchCellLifespan(of: queryCellID) else {
            return .delay(seconds: 20)
        }
        
        // ... or if the latest batch of packets has not been received from the tweak
        if CPTCollector.mostRecentPacket < end {
            return .delay(seconds: 20)
        }
        
        // We wait until we get a new cell measurements, as the disconnect packet can be sent rather late
        let qmiPackets: [NSManagedObjectID: ParsedQMIPacket]
        let ariPackets: [NSManagedObjectID: ParsedARIPacket]
        do {
            // Indication of QMI NAS Service with Network Reject packet
            // The packet's Reject Cause TLV could be interesting (0x03)
            // For a list of possibles causes, see: https://gitlab.freedesktop.org/mobile-broadband/libqmi/-/blob/main/src/libqmi-glib/qmi-enums-nas.h#L1663
            qmiPackets = try persistence.fetchQMIPackets(direction: .ingoing, service: 0x03, message: 0x0068, indication: true, start: start, end: end)
            
            // TODO: Find ARI Network Reject packet
            // Maybe IBINetRegistrationInfoIndCb -> [3] IBINetRegistrationRejectCause
            // There are also numerous IBI_NET_REGISTRATION_REJECT strings in libARI.dylib
            // For a list of ARI packets, see: https://github.com/seemoo-lab/aristoteles/blob/master/types/structure/libari_dylib.lua
            ariPackets = [:]
        } catch {
            throw CellVerifierError.fetchPackets(error)
        }
        
        if qmiPackets.count > 0 || ariPackets.count > 0 {
            // There's a suspicious packets, so we award zero points
            if let firstQMIPacketID = qmiPackets.keys.first {
                try persistence.storeRejectPacket(cellId: queryCellID, packetId: firstQMIPacketID)
            } else if let firstARIPacketID = ariPackets.keys.first {
                try persistence.storeRejectPacket(cellId: queryCellID, packetId: firstARIPacketID)
            }
            Self.logger.info("Reject packet present for cell (0/\(pointsPacket)): \(queryCell)")
            return .next(status: .verified, points: 0)
        } else {
            // All packets are fine, so we award 40 points :)
            Self.logger.info("Reject packet absent for cell (\(pointsPacket)/\(pointsPacket)): \(queryCell)")
            return .next(status: .verified, points: pointsPacket)
        }
    }
    
}
