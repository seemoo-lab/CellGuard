//
//  CGVerificationPipeline.swift
//  CellGuard
//
//  Created by Lukas Arnold on 29.04.24.
//

import Foundation
import CoreData
import OSLog

private struct NoConnectionDummyStage: VerificationStage {

    var id: Int16 = 1
    var name: String = "No Connection Defaults"
    var description: String = "Skips default measurements present when there's no connection."
    var points: Int16 = 0
    var waitForPackets: Bool = false

    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        // In ARI devices, a cell ID larger than Int32.max for UMTS connections, indicates that there's no cellular connection available.
        // Thus, there's nothing to verify.
        // We assume ARI modems use the constant 0xFFFFFFFF for that purpose (whereas Int32.max is 0x7FFFFFFF)
        if queryCell.technology == .UMTS && queryCell.cell == 0xFFFFFFFF {
            return .finishEarly
        }

        return .success()
    }

}

private enum ALSVerificationStageError: Error {
    case cantImportALSCells(Error)
    case cantAssignQueriedALSCell
}

private struct ALSVerificationStage: VerificationStage {

    var id: Int16 = 2
    var name: String = "ALS"
    var description: String = "Attempts to retrieve the cell's counterpart from Apple Location Services (ALS)."
    var points: Int16 = 20
    var waitForPackets: Bool = false

    private let persistence = PersistenceController.shared
    private let alsClient = ALSClient()

    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        // Try to find the corresponding ALS cell in our database
        if let alsObjectId = try? persistence.assignExistingALSIfPossible(to: queryCellId) {
            logger.info("ALS verification using the local database successful")
            return .success(related: VerificationStageRelatedObjects(cellAls: alsObjectId))
        }

        // If we can't find the cell in our database, we'll query ALS (and return to this thread)
        logger.debug("Requesting tweak cell from the remote ALS database")
        let alsCells = try await alsClient.requestCells(origin: queryCell)
        logger.debug("Received \(alsCells.count) cells from ALS")

        // Remove query cells with are only are rough approximation
        let preciseAlsCells = alsCells.filter { $0.hasCellId() }

        // Check if the resulting ALS cell is valid
        if !(preciseAlsCells.first?.isValid() ?? false) {
            logger.info("ALS verification failed as the first cell is not valid")
            // If not, do not award any points in this category
            return .fail()
        }

        // If the cell is valid, import all cells of the ALS response ...
        do {
            try persistence.importALSCells(from: preciseAlsCells)
        } catch {
            throw ALSVerificationStageError.cantImportALSCells(error)
        }

        // ... and assign the ALS cell to the tweak cell
        if let alsObjectId = try persistence.assignExistingALSIfPossible(to: queryCellId) {
            return .success(related: VerificationStageRelatedObjects(cellAls: alsObjectId))
        } else {
            // If that fails, we throw an error
            throw ALSVerificationStageError.cantAssignQueriedALSCell
        }
    }

}

private struct DistanceVerificationStage: VerificationStage {

    var id: Int16 = 3
    var name: String = "Distance"
    var description: String = "Calculates the distance (with error margins) between your recorded location and the cell's location stored in ALS."
    var points: Int16 = 20
    var waitForPackets: Bool = false

    private let persistence = PersistenceController.shared

    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        // If there's no ALS cell assigned to this cell, we skip this stage
        if persistence.fetchCellAttribute(cell: queryCellId, extract: { $0.appleDatabase == nil }) ?? true {
            return .success()
        }

        // Try to assign a location to the cell
        let (foundLocation, cellCollected) = try persistence.assignLocation(to: queryCellId)
        if !foundLocation {
            // We've missing a location for the cell, so ...
            if (cellCollected ?? Date.distantPast) < Date().addingTimeInterval(-5 * 60) {
                // If the cell is older than five minutes, we assume that we won't get the location data and just mark the location as checked
                logger.info("No location found for cell")
                return .success()
            } else {
                // If the cell is younger than five minutes, we retry after 30s
                return .delay(seconds: 30)
            }
        }

        // Calculate the distance between the location assigned to the tweak cells & the ALS cell
        guard let (distance, locationUserId, alsCellId) = persistence.calculateDistance(tweakCell: queryCellId) else {
            // If we can't get the distance, we delay the verification
            logger.warning("Can't calculate distance")
            return .delay(seconds: 60)
        }

        // The score is a percentage of how likely the cell is evil, so we calculate an inverse of that and multiple it by the points
        logger.info("Location verified for cell")
        let distancePoints = Int16(Double(points) * (1.0 - distance.score()))
        return .partial(points: distancePoints, related: VerificationStageRelatedObjects(cellAls: alsCellId, locationUser: locationUserId))
    }

}

private struct FrequencyVerificationStage: VerificationStage {

    var id: Int16 = 4
    var name: String = "Frequency"
    var description: String = "Compares the cell's frequency and PID information with those stored in ALS. This information is not available for every cell."
    var points: Int16 = 8
    var waitForPackets: Bool = false

    private let persistence = PersistenceController.shared

    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        // ALS only provides us with the attributes (PID & EARFCN) for some LTE cells.
        // We could expand those checks for 5GNR SA cells (ARFCN), but we would require a real 5G SA cell to confirm the data of ALS.
        if queryCell.technology == .LTE {
            let compareData = persistence.fetchCellAttribute(cell: queryCellId) { measurement in
                if let alsCell = measurement.appleDatabase {
                    return (
                        measurement: (pid: measurement.physicalCell, frequency: measurement.frequency),
                        als: (pid: alsCell.physicalCell, frequency: alsCell.frequency),
                        alsObjectId: alsCell.objectID
                    )
                }
                return nil
            }
            if let (measurement, als, alsObjectId) = compareData {
                var localPoints = points

                if measurement.frequency > 0 && als.frequency > 0 && measurement.frequency != als.frequency {
                    localPoints -= 6
                    logger.info("Frequency Verification - EARFCN not equal: \(measurement.frequency) != \(als.frequency)")
                }
                if measurement.pid > 0 && als.pid > 0 && measurement.pid != als.pid {
                    localPoints -= 2
                    logger.info("Frequency Verification - PID not equal: \(measurement.pid) != \(als.pid)")
                }

                return .partial(points: localPoints, related: VerificationStageRelatedObjects(cellAls: alsObjectId))
            } else {
                logger.debug("Frequency Verification: No data for comparison")
            }
        }

        // ALS didn't provide any frequency information, so we skip this stage
        return .success()
    }

}

private struct BandwidthVerificationStage: VerificationStage {

    var id: Int16 = 5
    var name: String = "Bandwidth"
    var description: String = "Assigns points based on the cell's bandwidth as achieving a higher bandwidth is more costly for attackers."
    var points: Int16 = 2
    var waitForPackets: Bool = false

    private let persistence = PersistenceController.shared

    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        if queryCell.technology == .LTE {
            // For now, we could only verify it for LTE but not for 5GNR SA

            // If we didn't record a cell's bandwidth it's stored as zero in our DB
            if let bandwidth = persistence.fetchCellAttribute(cell: queryCellId, extract: { $0.bandwidth }), bandwidth > 0 {

                // The bandwidth measurement that we get from the cell data, is multiplied by four
                // The max bandwidth for LTE frequencies is 20 MHz, thus the max Apple-internal value is 100
                // https://www.lte-anbieter.info/ratgeber/frequenzen-lte.php
                // We subtract points linearly if it's lower
                let bandwidthPercentage = (Double(bandwidth) / 100.0).clamped(to: 0.0...1.0)
                return .partial(points: Int16(floor(Double(points) * bandwidthPercentage)))
            }
        }

        // The cell's measurement didn't provide any frequency information, so we skip this stage
        return .success()
    }

}

private struct RejectPacketVerificationStage: VerificationStage {

    var id: Int16 = 6
    var name: String = "Reject Packet"
    var description: String = "Scans the baseband packets for a signaling an unexpected disconnection from network (reject)."
    var points: Int16 = 30
    var waitForPackets: Bool = true

    let persistence = PersistenceController.shared

    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        let appMode = UserDefaults.standard.dataCollectionMode()

        // Delay the verification 20s if no newer cell exists, i.e., we are still connected to this cell
        guard let (start, end, _, simSlotID) = try persistence.fetchCellLifespan(of: queryCellId) else {
            // We won't receive new packets in the analysis mode
            if appMode == DataCollectionMode.none {
                return .success()
            } else {
                return .delay(seconds: 20)
            }
        }

        #if JAILBREAK
        // ... or if the latest batch of packets has not been received from the tweak
        if appMode == .automatic && CPTCollector.mostRecentPacket < end {
            return .delay(seconds: 20)
        }
        #endif

        // TODO: Sometimes those packets are attributed to the wrong cell in ARI

        // We wait until we get a new cell measurements, as the disconnect packet can be sent rather late
        let qmiPackets: [NSManagedObjectID: ParsedQMIPacket]
        let ariPackets: [NSManagedObjectID: ParsedARIPacket]
        // Indication of QMI NAS Service with Network Reject packet
        // The packet's Reject Cause TLV could be interesting (0x03)
        // For a list of possibles causes, see: https://gitlab.freedesktop.org/mobile-broadband/libqmi/-/blob/main/src/libqmi-glib/qmi-enums-nas.h#L1663
        // This fetch request is just slow and I guess we can't do anything about it as there is a large number of packets
        qmiPackets = try persistence.fetchIndexedQMIPackets(start: start, end: end, simSlotID: simSlotID, reject: true)

        // Maybe IBINetRegistrationInfoIndCb -> [3] IBINetRegistrationRejectCause
        // There are also numerous IBI_NET_REGISTRATION_REJECT strings in libARI.dylib
        // For a list of ARI packets, see: https://github.com/seemoo-lab/aristoteles/blob/master/types/structure/libari_dylib.lua
        let localAriPackets = try persistence.fetchIndexedARIPackets(start: start, end: end, reject: true)
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

        if qmiPackets.count > 0 || ariPackets.count > 0 {
            // There's a suspicious packets, so we award zero points
            logger.info("Reject packet(s) present")
            return .fail(related: VerificationStageRelatedObjects(packetsAri: Array(ariPackets.keys), packetsQmi: Array(qmiPackets.keys)))
        } else {
            // All packets are fine, so we award 40 points :)
            logger.info("Reject packet(s) absent")
            return .success(related: nil)
        }
    }

}

private struct SignalStrengthVerificationStage: VerificationStage {

    var id: Int16 = 7
    var name: String = "Signal Strength"
    var description: String = "Extracts the signal strength from the baseband packets and subtracts points if it is unusually high."
    var points: Int16 = 20
    var waitForPackets: Bool = true

    let persistence = PersistenceController.shared

    func verify(queryCell: ALSQueryCell, queryCellId: NSManagedObjectID, logger: Logger) async throws -> VerificationStageResult {
        let dataCollectionMode = UserDefaults.standard.dataCollectionMode()

        // Delay the verification 20s if no newer cell exists, i.e., we are still connected to this cell
        guard let (start, end, _, simSlotID) = try persistence.fetchCellLifespan(of: queryCellId) else {
            // We won't receive new packets in the analysis mode
            if dataCollectionMode == DataCollectionMode.none {
                return .success()
            } else {
                return .delay(seconds: 20)
            }
        }

        #if JAILBREAK
        // ... or if the latest batch of packets has not been received from the tweak
        if dataCollectionMode == .automatic && CPTCollector.mostRecentPacket < end {
            return .delay(seconds: 20)
        }
        #endif

        // TODO: calculate the awarded points exponentially, but for now it's a binary decision
        // TODO: Sometimes awarded to the wrong cell(?)

        // QMI: Signal Info Indication
        let fetchedQmiPackets = try persistence.fetchIndexedQMIPackets(start: start, end: end, simSlotID: simSlotID, signal: true)
        let qmiSignalInfo = fetchedQmiPackets
            .compactMap { (_, packet) -> ParsedQMISignalInfoIndication? in
                do {
                    return try ParsedQMISignalInfoIndication(qmiPacket: packet)
                } catch {
                    logger.warning("Can't extract signal strengths from a QMI packet")
                    return nil
                }
            }
        if qmiSignalInfo.count > 0 {
            qmiSignalInfo.forEach { (infoIndication: ParsedQMISignalInfoIndication) in
                logger.debug("Signal Strength QMI: GSM: \(String(describing: infoIndication.gsm)) LTE: \(infoIndication.lte.debugDescription) NR: \(infoIndication.nr.debugDescription)")
            }
            let gsmInfo = qmiSignalInfo.compactMap {$0.gsm}
            let lteInfo = qmiSignalInfo.filter {$0.nr?.rsrp == NRSignalStrengthQMI.missing}.compactMap {$0.lte}
            let nrInfo = qmiSignalInfo.compactMap {$0.nr}.filter {$0.rsrp != nil}

            if nrInfo.count > 0 {
                let rsrpAvg = average(nrInfo.compactMap {$0.rsrp})
                let rsrqAvg = average(nrInfo.compactMap {$0.rsrq})
                let snrAvg = average(nrInfo.compactMap {$0.snr})

                // We don't have any measurements for 5GNR
                if let rsrpAvg = rsrpAvg,
                   let rsrqAvg = rsrqAvg,
                   let snrAvg = snrAvg,
                   rsrqAvg >= -4 && rsrpAvg >= -100 && snrAvg >= 200 {
                    // TODO: Above max. 25 and below and exponential thingy?
                    logger.info("Signal Strength QMI: 5GNR SUS")
                    return .fail(related: VerificationStageRelatedObjects(packetsQmi: Array(fetchedQmiPackets.keys)))
                }
            } else if lteInfo.count > 0 {
                let rssiAvg = average(lteInfo.map {$0.rssi})
                let rsrqAvg = average(lteInfo.map {$0.rsrq})
                let rsrpAvg = average(lteInfo.map {$0.rsrp})
                let snrAvg = average(lteInfo.map {$0.snr})

                if let rssiAvg = rssiAvg,
                   let rsrqAvg = rsrqAvg,
                   let rsrpAvg = rsrpAvg,
                   let snrAvg = snrAvg,
                    rssiAvg >= -70 && rsrqAvg >= -4 && rsrpAvg >= -100 && snrAvg >= 200 {
                    logger.info("Signal Strength QMI: LTE SUS")
                    return .fail(related: VerificationStageRelatedObjects(packetsQmi: Array(fetchedQmiPackets.keys)))
                }
            } else if gsmInfo.count > 0 {
                let rssiAvg = average(gsmInfo.compactMap {$0})

                // We don't have any measurements for GSM
                if let rssiAvg = rssiAvg,
                   rssiAvg >= -60 {
                    logger.info("Signal Strength QMI: GSM SUS")
                    return .fail(related: VerificationStageRelatedObjects(packetsQmi: Array(fetchedQmiPackets.keys)))
                }
            }
        }

        // ARI: IBINetRadioSignalIndCb
        let fetchedAriPackets = try persistence.fetchIndexedARIPackets(start: start, end: end, signal: true)
        let ariSignalInfo = fetchedAriPackets
            .compactMap { (_, packet) -> ParsedARIRadioSignalIndication? in
                do {
                    return try ParsedARIRadioSignalIndication(ariPacket: packet)
                } catch {
                    logger.warning("Can't extract signal strengths from a ARI packet")
                    return nil
                }
            }
            .compactMap { (infoIndication: ParsedARIRadioSignalIndication) -> (ssr: Double, sqr: Double)? in
                let ssr = Double(infoIndication.signalStrength) / Double(infoIndication.signalStrengthMax)
                let sqr = Double(infoIndication.signalQuality) / Double(infoIndication.signalQualityMax)
                logger.debug("Signal Strength ARI: \(String(describing: infoIndication))")

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
                logger.info("Signal Strength ARI: SUS")
                return .fail(related: VerificationStageRelatedObjects(packetsAri: Array(fetchedAriPackets.keys)))
            }
        }

        return .success(related: VerificationStageRelatedObjects(packetsAri: Array(fetchedAriPackets.keys), packetsQmi: Array(fetchedQmiPackets.keys)))
    }

    private func average(_ values: [any FixedWidthInteger]) -> Double? {
        let count = Double(values.count)
        if count == 0 {
            return nil
        }

        let sum = values.map {Double($0)}.reduce(0, +)
        return sum / count
    }

}

struct CGVerificationPipeline: VerificationPipeline {

    var logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CGVerificationPipeline.self)
    )

    var id: Int16 = 1
    var name = "CellGuard"

    var after: (any VerificationPipeline)?
    var stages: [any VerificationStage] = [
        NoConnectionDummyStage(),
        ALSVerificationStage(),
        DistanceVerificationStage(),
        FrequencyVerificationStage(),
        BandwidthVerificationStage(),
        RejectPacketVerificationStage(),
        SignalStrengthVerificationStage()
    ]

    static var instance = CGVerificationPipeline()

}
