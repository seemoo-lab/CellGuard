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

enum VerificationStageResult {
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
    
    public static let pointsMax = 100
    public static let pointsSuspiciousThreshold = 95
    public static let pointsUntrustedThreshold = 50
    
    public static let pointsALS = 20
    public static let pointsLocation = 20
    public static let pointsFrequency = 8
    public static let pointsBandwidth = 2
    public static let pointsRejectPacket = 30
    public static let pointsSignalStrength = 20
    
    public static let pointsFastVerification = Self.pointsALS + Self.pointsLocation + Self.pointsFrequency + Self.pointsBandwidth
    
    private let persistence = PersistenceController.shared
    private let alsClient = ALSClient()
    
    init() {
        assert(Self.pointsALS + Self.pointsLocation + Self.pointsFrequency + Self.pointsBandwidth + Self.pointsRejectPacket + Self.pointsSignalStrength == 100, "The sum of all points must be 100")
    }
    
    func verifyFirst() async throws -> Bool {
        let queryCell: (NSManagedObjectID, ALSQueryCell, CellStatus?, Int16)?
        do {
            queryCell = try persistence.fetchLatestUnverifiedTweakCells(count: 1)
        } catch {
            throw CellVerifierError.fetchCellToVerify(error)
        }
        
        // Check if there is a cell to verify
        guard let (queryCellID, queryCell, queryCellStatus, startScore) = queryCell else {
            // There is currently no cell to verify
            return false
        }
        
        // Check if the cell status was parsed successfully
        guard var queryCellStatus = queryCellStatus else {
            throw CellVerifierError.invalidCellStatus
        }
        
        var score = startScore
        
        // Continue with the correct verification stage (at max. 10 verification stages each time)
        outer: for i in 0...10 {
            if i == 10 {
                Self.logger.warning("Reached 10 verification iterations for \(queryCell)")
            }
            
            // Run the verification stage for the cell's current state
            let result = try await verifyStage(status: queryCellStatus, queryCell: queryCell, queryCellID: queryCellID)
            
            // Based on the stage's result, we choose our course of action
            switch (result) {
                
            case let .next(nextStatus, points):
                Self.logger.debug("Result: .next(\(nextStatus.rawValue), \(points))")
                // We store the resulting status and award the points, then the while-loop continues
                score += Int16(points)
                queryCellStatus = nextStatus
                if nextStatus == .verified {
                    break outer
                }
                
            case let .delay(delay):
                Self.logger.debug("Delay: .next(\(delay))")
                // We store the delay in the database and stop the verification loop
                try persistence.storeVerificationDelay(cellId: queryCellID, seconds: delay)
                break outer
            }
        }
        
        try persistence.storeCellStatus(cellId: queryCellID, status: queryCellStatus, score: score)
        
        // We've verified a cell, so return true
        return true
    }
    
    private func verifyStage(status: CellStatus, queryCell: ALSQueryCell, queryCellID: NSManagedObjectID) async throws -> VerificationStageResult {
        Self.logger.debug("Verification Stage: \(status.rawValue) for \(queryCellID) - \(queryCell)")
        switch (status) {
        case .imported:
            return try await verifyUsingALS(queryCell: queryCell, queryCellID: queryCellID)
        case .processedCell:
            return try await verifyDistance(queryCell: queryCell, queryCellID: queryCellID)
        case .processedLocation:
            return try await verifyFrequency(queryCell: queryCell, queryCellID: queryCellID)
        case .processedFrequency:
            return try await verifyBandwidth(queryCell: queryCell, queryCellID: queryCellID)
        case .processedBandwidth:
            return try await verifyRejectPacket(queryCell: queryCell, queryCellID: queryCellID)
        case .processedRejectPacket:
            return try await verifySignalStrength(queryCell: queryCell, queryCellID: queryCellID)
        case .verified:
            throw CellVerifierError.verifiedCellFetched
        }
    }
    
    private func verifyUsingALS(queryCell: ALSQueryCell, queryCellID: NSManagedObjectID) async throws -> VerificationStageResult {
        // Try to find the corresponding ALS cell in our database
        if let existing = try? persistence.assignExistingALSIfPossible(to: queryCellID), existing {
            Self.logger.info("ALS verification using the local database successful: \(queryCell)")
            return .next(status: .processedCell, points: Self.pointsALS)
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
            // If not, do not award any points in this category
            return .next(status: .processedCell, points: 0)
        }
        
        // If the cell is valid, import all cells of the ALS response
        do {
            try persistence.importALSCells(from: preciseAlsCells, source: queryCellID)
        } catch {
            throw CellVerifierError.importALSCells(error)
        }
        
        // Issue: ALS does not include PID & EARFCN for the requested cells, but all others.
        // We require this data for LTE cell verification, so we request the first neighboring cell to retrieve the attributes for our original cell.
        /* if let first = preciseAlsCells.first, first.technology == .LTE, first.physicalCell == 0 || first.frequency == 0, preciseAlsCells.count >= 2 {
            // Query ALS using the cell's first neighbor and search for the cell in the query results
            let updatedFirst = try await alsClient.requestCells(origin: preciseAlsCells[1])
                .filter { $0.hasCellId() && $0.isValid() }
                .first { $0.compareToRequestAttributes(other: first) }
            
            // If successful, update the cell's properties
            if let updatedFirst = updatedFirst {
                do {
                    try persistence.importALSCells(from: [updatedFirst], source: queryCellID)
                } catch {
                    throw CellVerifierError.importALSCells(error)
                }
            }
        } */
        
        // Award the points based on the distance
        Self.logger.info("ALS verification successful (\(Self.pointsALS)/\(Self.pointsALS)): \(queryCell)")
        return .next(status: .processedCell, points: Self.pointsALS)
    }
    
    private func verifyDistance(queryCell: ALSQueryCell, queryCellID: NSManagedObjectID) async throws -> VerificationStageResult {
        if persistence.fetchCellAttribute(cell: queryCellID, extract: { $0.verification == nil }) ?? true {
            
            return .next(status: .processedLocation, points: Self.pointsLocation)
        }
        
        // Try to assign a location to the cell
        let (foundLocation, cellCollected) = try persistence.assignLocation(to: queryCellID)
        if !foundLocation {
            // We've missing a location for the cell, so ...
            if (cellCollected ?? Date.distantPast) < Date().addingTimeInterval(-5 * 60) {
                // If the cell is older than five minutes, we assume that we won't get the location data and just mark the location as checked
                Self.logger.info("No location found for cell (\(Self.pointsLocation)/\(Self.pointsLocation)): \(queryCell)")
                return .next(status: .processedLocation, points: Self.pointsLocation)
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
        let distancePoints = Int(Double(Self.pointsLocation) * (1.0 - distance.score()))
        Self.logger.info("Location verified for cell (\(distancePoints)/\(Self.pointsLocation)): \(queryCell)")
        return .next(status: .processedLocation, points: distancePoints)
    }
    
    private func verifyFrequency(queryCell: ALSQueryCell, queryCellID: NSManagedObjectID) async throws -> VerificationStageResult {
        // ALS only provides us with the attributes (PID & EARFCN) for LTE cells
        // We could expand those checks for 5GNR SA cells (ARFCN), but we would require a real 5G SA cell to confirm the data of ALS
        if queryCell.technology == .LTE {
            let compareData = persistence.fetchCellAttribute(cell: queryCellID) { measurement in
                if let alsCell = measurement.verification {
                    return (
                        measurement: (pid: measurement.physicalCell, frequency: measurement.frequency),
                        als: (pid: alsCell.physicalCell, frequency: alsCell.frequency)
                    )
                }
                return nil
            }
            if let (measurement, als) = compareData {
                var localPoints = Self.pointsFrequency
                
                if measurement.frequency > 0 && als.frequency > 0 && measurement.frequency != als.frequency {
                    localPoints -= 6
                    Self.logger.info("Frequency Verification - EARFCN not equal: \(measurement.frequency) != \(als.frequency)")
                }
                if measurement.pid > 0 && als.pid > 0 && measurement.pid != als.pid {
                    localPoints -= 2
                    Self.logger.info("Frequency Verification - PID not equal: \(measurement.pid) != \(als.pid)")
                }
                
                return .next(status: .processedFrequency, points: localPoints)
            } else {
                Self.logger.debug("Frequency Verification: No data for comparison")
            }
        }
        
        return .next(status: .processedFrequency, points: Self.pointsFrequency)
    }
    
    private func verifyBandwidth(queryCell: ALSQueryCell, queryCellID: NSManagedObjectID) async throws -> VerificationStageResult {
        if queryCell.technology == .LTE {
            // For now, we could only verify it for LTE but not for 5GNR SA
            
            // If we didn't record a cell's bandwidth it's stored as zero in our DB
            if let bandwidth = persistence.fetchCellAttribute(cell: queryCellID, extract: { $0.bandwidth }), bandwidth > 0 {
                
                // The bandwidth measurement that we get from the cell data, is multiplied by four
                // The max bandwidth for LTE frequencies is 20 MHz, thus the max Apple-internal value is 100
                // https://www.lte-anbieter.info/ratgeber/frequenzen-lte.php
                // We subtract points linearly if it's lower
                let bandwidthPercentage = (Double(bandwidth) / 100.0).clamped(to: 0.0...1.0)
                return .next(status: .processedBandwidth, points: Int(floor(Double(Self.pointsBandwidth) * bandwidthPercentage)))
            }
        }
        
        return .next(status: .processedBandwidth, points: Self.pointsBandwidth)
    }

    private func verifyRejectPacket(queryCell: ALSQueryCell, queryCellID: NSManagedObjectID) async throws -> VerificationStageResult {
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
            // This fetch request is just slow and I guess we can't do anything about it as there is a large number of packets
            qmiPackets = try persistence.fetchQMIPackets(direction: .ingoing, service: 0x03, message: 0x0068, indication: true, start: start, end: end)
            
            // Maybe IBINetRegistrationInfoIndCb -> [3] IBINetRegistrationRejectCause
            // There are also numerous IBI_NET_REGISTRATION_REJECT strings in libARI.dylib
            // For a list of ARI packets, see: https://github.com/seemoo-lab/aristoteles/blob/master/types/structure/libari_dylib.lua
            let localAriPackets = try persistence.fetchARIPackets(direction: .ingoing, group: 7, type: 769, start: start, end: end)
                .filter { (_, packet) in
                    guard let registrationStatus = packet.tlvs.first(where: { $0.type == 2 })?.uint() else {
                        return false
                    }
                    
                    // The registration status must be IBI_NET_REGISTRATION_STATUS_LIMITED_SERVICE (2)
                    // See: https://github.com/seemoo-lab/aristoteles/blob/07dbbaefc3f32bf007210219b6e2e4e84d82233f/types/asstring/ari_tlv_as_string_data.lua#L1434
                    if registrationStatus != 2 {
                        return false
                    }
                    
                    guard let registrationRejectCause = packet.tlvs.first(where: { $0.type == 3 })?.uint() else {
                        return false
                    }
                    
                    // The registration reject cause must either be
                    // - IBI_NET_REGISTRATION_REJECT_CAUSE_FORB_PLMN (9)
                    // - IBI_NET_REGISTRATION_REJECT_CAUSE_INTERNAL_FAILURE (15)
                    // See: https://github.com/seemoo-lab/aristoteles/blob/07dbbaefc3f32bf007210219b6e2e4e84d82233f/types/asstring/ari_tlv_as_string_data.lua#L1405
                    return [9, 15].contains(registrationRejectCause)
                }
            // Only fail the verification if two packets matching the criteria appeared for the same cell
            ariPackets = localAriPackets.count >= 2 ? localAriPackets : [:]
            // TODO: Sometimes those packets are attributed to the wrong cell in ARI
            
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
            Self.logger.info("Reject packet present for cell (0/\(Self.pointsRejectPacket)): \(queryCell)")
            return .next(status: .processedRejectPacket, points: 0)
        } else {
            // All packets are fine, so we award 40 points :)
            Self.logger.info("Reject packet absent for cell (\(Self.pointsRejectPacket)/\(Self.pointsRejectPacket)): \(queryCell)")
            return .next(status: .processedRejectPacket, points: Self.pointsRejectPacket)
        }
    }
    
    func verifySignalStrength(queryCell: ALSQueryCell, queryCellID: NSManagedObjectID) async throws -> VerificationStageResult {
        // Delay the verification 20s if no newer cell exists, i.e., we are still connected to this cell
        guard let (start, end, _) = try persistence.fetchCellLifespan(of: queryCellID) else {
            return .delay(seconds: 20)
        }
        
        // ... or if the latest batch of packets has not been received from the tweak
        if CPTCollector.mostRecentPacket < end {
            return .delay(seconds: 20)
        }
        
        // TODO: Store the signal strength in the database
        // We could also calculate the awarded points exponentially, but for now it's a binary decision
        
        // Idea to speed-up the packet fetching process: "Skip Tables" -> Store references to the relevant types of packets in a separate table, which we can query faster
        
        // QMI: Signal Info Indication
        let qmiSignalInfo = try persistence.fetchQMIPackets(direction: .ingoing, service: 0x03, message: 0x0051, indication: true, start: start, end: end)
            .compactMap { (_, packet) in
                do {
                    return try ParsedQMISignalInfoIndication(qmiPacket: packet)
                } catch {
                    Self.logger.warning("Can't extract signal strengths from a QMI packet")
                    return nil
                }
            }
        if qmiSignalInfo.count > 0 {
            qmiSignalInfo.forEach { (infoIndication: ParsedQMISignalInfoIndication) in
                Self.logger.debug("Signal Strength QMI: GSM: \(String(describing: infoIndication.gsm)) LTE: \(infoIndication.lte.debugDescription) NR: \(infoIndication.nr.debugDescription)")
            }
            let gsmInfo = qmiSignalInfo.compactMap {$0.gsm}
            let lteInfo = qmiSignalInfo.filter {$0.nr?.rsrp == NRSignalStrengthQMI.missing}.compactMap {$0.lte}
            let nrInfo = qmiSignalInfo.compactMap {$0.nr}.filter {$0.rsrp != NRSignalStrengthQMI.missing}
            
            if nrInfo.count > 0 {
                let rsrpAvg = nrInfo.map {Double($0.rsrp)}.reduce(0.0, +) / Double(nrInfo.count)
                let rsrqAvg = nrInfo.map {Double($0.rsrq)}.reduce(0.0, +) / Double(nrInfo.count)
                let snrAvg = nrInfo.map {Double($0.snr)}.reduce(0.0, +) / Double(nrInfo.count)
        
                // We don't have any measurements for 5GNR
                if rsrqAvg >= -4 && rsrpAvg >= -100 && snrAvg >= 200 {
                    // TODO: Above max. 25 and below and exponential thingy?
                    Self.logger.info("Signal Strength QMI: 5GNR SUS")
                    return .next(status: .verified, points: 0)
                }
            } else if lteInfo.count > 0 {
                let rssiAvg = lteInfo.map {Double($0.rssi)}.reduce(0.0, +) / Double(lteInfo.count)
                let rsrqAvg = lteInfo.map {Double($0.rsrq)}.reduce(0.0, +) / Double(lteInfo.count)
                let rsrpAvg = lteInfo.map {Double($0.rsrp)}.reduce(0.0, +) / Double(lteInfo.count)
                let snrAvg = lteInfo.map {Double($0.snr)}.reduce(0.0, +) / Double(lteInfo.count)
                
                if rssiAvg >= -70 && rsrqAvg >= -4 && rsrpAvg >= -100 && snrAvg >= 200 {
                    Self.logger.info("Signal Strength QMI: LTE SUS")
                    return .next(status: .verified, points: 0)
                }
            } else if gsmInfo.count > 0 {
                let rssiAvg = gsmInfo.map {Double($0)}.reduce(0.0, +) / Double(gsmInfo.count)
                
                // We don't have any measurements for GSM
                if rssiAvg >= -60 {
                    Self.logger.info("Signal Strength QMI: GSM SUS")
                    return .next(status: .verified, points: 0)
                }
            }
        }
        
        // ARI: IBINetRadioSignalIndCb
        let ariSignalInfo = try persistence.fetchARIPackets(direction: .ingoing, group: 9, type: 772, start: start, end: end)
            .compactMap { (_, packet) in
                do {
                    return try ParsedARIRadioSignalIndication(ariPacket: packet)
                } catch {
                    Self.logger.warning("Can't extract signal strengths from a ARI packet")
                    return nil
                }
            }
            .compactMap { (infoIndication: ParsedARIRadioSignalIndication) -> (ssr: Double, sqr: Double)? in
                let ssr = Double(infoIndication.signalStrength) / Double(infoIndication.signalStrengthMax)
                let sqr = Double(infoIndication.signalQuality) / Double(infoIndication.signalQualityMax)
                Self.logger.debug("Signal Strength ARI: \(String(describing: infoIndication))")
                
                if sqr > 1 {
                    // The iPhone has no service (usually: SQ = 99 and SQM = 7)
                    return nil
                }
                
                return (ssr, sqr)
            }
        if ariSignalInfo.count > 0 {
            let ssrAvg = ariSignalInfo.map {$0.ssr}.reduce(0.0, +) / Double(ariSignalInfo.count)
            let sqrAvg = ariSignalInfo.map {$0.sqr}.reduce(0.0, +) / Double(ariSignalInfo.count)
            
            if ssrAvg > 0.65 && sqrAvg > 0.85 {
                Self.logger.info("Signal Strength ARI: SUS")
                return .next(status: .verified, points: 0)
            }
        }
        
        
        return .next(status: .verified, points: Self.pointsSignalStrength)
    }
    
}
