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
                return taskResult
            }
            
            // Set a timeout of 10s for each individual cell verification
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: UInt64(10) * NSEC_PER_SEC)
                verifyTask.cancel()
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
                Self.logger.warning("Cell verification timed out after 10s")
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
        guard let queryCellStatus = queryCellStatus else {
            throw CellVerifierError.invalidCellStatus
        }
        
        Self.logger.debug("Verifying cell \(queryCellID): \(queryCell)")
        // Continue with the correct verification stage
        switch (queryCellStatus) {
        case .imported:
            try await verifyUsingALS(queryCell: queryCell, queryCellID: queryCellID)
        case .processedCell:
            try await verifyDistance(queryCell: queryCell, queryCellID: queryCellID)
        case .processedLocation:
            try await verifyPacket(queryCell: queryCell, queryCellID: queryCellID)
        case .verified:
            throw CellVerifierError.verifiedCellFetched
        }
        // We've verified a cell, so return true
        return true
    }
    
    private func verifyUsingALS(queryCell: ALSQueryCell, queryCellID: NSManagedObjectID) async throws {
        // Try to find the corresponding ALS cell in our database
        if let existing = try? persistence.assignExistingALSIfPossible(to: queryCellID), existing {
            Self.logger.info("Verified tweak cell using the local ALS database: \(queryCell)")
            try? persistence.storeCellStatus(cellId: queryCellID, status: .processedLocation, addToScore: Int16(pointsALS))
            try await verifyDistance(queryCell: queryCell, queryCellID: queryCellID)
            return
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
            // If not, do not add any points to it and continue with the packet verification
            try? persistence.storeCellStatus(cellId: queryCellID, status: .processedLocation, addToScore: 0)
            try await verifyPacket(queryCell: queryCell, queryCellID: queryCellID)
            return
        }
        
        // If the cell is valid, import all cells of the ALS response
        do {
            try persistence.importALSCells(from: alsCells, source: queryCellID)
        } catch {
            throw CellVerifierError.importALSCells(error)
        }
        
        // Award the points based on the distance
        try? persistence.storeCellStatus(cellId: queryCellID, status: .processedCell, addToScore: Int16(pointsALS))
        try await verifyDistance(queryCell: queryCell, queryCellID: queryCellID)
    }
    
    private func verifyDistance(queryCell: ALSQueryCell, queryCellID: NSManagedObjectID) async throws {
        // Try to assign a location to the cell
        let (foundLocation, cellCollected) = try persistence.assignLocation(to: queryCellID)
        if !foundLocation {
            // We've missing a location for the cell, so ...
            if (cellCollected ?? Date.distantPast) < Date().addingTimeInterval(-5 * 60) {
                // If the cell is older than five minutes, we assume that we won't get the location data and just mark the location as checked
                try? persistence.storeCellStatus(cellId: queryCellID, status: .processedLocation, addToScore: Int16(pointsLocation))
            } else {
                // If the cell is younger than five minutes, we retry after 30s
                try? persistence.storeVerificationDelay(cellId: queryCellID, seconds: 30)
            }
        }
        
        // Calculate the distance between the location assigned to the tweak cells & the ALS cell
        // TODO: Improve distance calculation by choosing the best location data near the cell (maybe wait 5 seconds or so?)
        guard let distance = persistence.calculateDistance(tweakCell: queryCellID) else {
            // If we can't get
            Self.logger.warning("Can't calculate distance for cell \(queryCellID)")
            try? persistence.storeVerificationDelay(cellId: queryCellID, seconds: 60)
            return
        }
        
        let distancePoints = Double(pointsLocation) * (1.0 - distance.score())
        try? persistence.storeCellStatus(cellId: queryCellID, status: .processedLocation, addToScore: Int16(distancePoints))
        
        try await verifyPacket(queryCell: queryCell, queryCellID: queryCellID)
    }
    
    private func verifyPacket(queryCell: ALSQueryCell, queryCellID: NSManagedObjectID) async throws {
        // Delay the verification 20s if no newer cell exists, i.e., we are still connected to this cell
        guard let (start, end, _) = try persistence.fetchCellLifespan(of: queryCellID) else {
            try persistence.storeVerificationDelay(cellId: queryCellID, seconds: 20)
            return
        }
        
        // ... or if the latest batch of packets haven't been received from the tweak
        if CPTCollector.mostRecentPacket < end {
            try persistence.storeVerificationDelay(cellId: queryCellID, seconds: 20)
            return
        }
        
        // We wait until we get a new cell measurements, as the disconnect packet can be sent rather late
        let qmiPackets: [ParsedQMIPacket]
        let ariPackets: [ParsedARIPacket]
        do {
            // Indication of QMI NAS Service with Network Reject packet
            qmiPackets = try persistence.fetchQMIPackets(direction: .ingoing, service: 0x03, message: 0x0068, indication: true, start: start, end: end)
            
            // TODO: Find ARI Network Reject packet
            // Maybe IBINetRegistrationInfoIndCb -> [3] IBINetRegistrationRejectCause
            // https://github.com/seemoo-lab/aristoteles/blob/master/types/structure/libari_dylib.lua
            ariPackets = []
        } catch {
            throw CellVerifierError.fetchPackets(error)
        }
        
        if qmiPackets.count > 0 || ariPackets.count > 0 {
            // There's a suspicious packets, so we award zero points
            try? persistence.storeCellStatus(cellId: queryCellID, status: .verified, addToScore: 0)
        } else {
            // All packets are fine, so we award 40 points :)
            try? persistence.storeCellStatus(cellId: queryCellID, status: .verified, addToScore: Int16(pointsPacket))
        }
    }
    
}
