//
//  SampleCellParser.swift
//  CellGuard
//
//  Created by mp on 01.04.25.
//

import Foundation

typealias CellInfo = [String: Any]
typealias CellSample = [CellInfo]

extension CCTParser {

    func parse(_ sample: CellSample) throws -> CCTCellProperties {
        if sample.isEmpty {
            throw CCTParserError.emptySample(sample)
        }
        guard let metaInfos = sample.last else {
            throw CCTParserError.emptySample(sample)
        }

        guard let doubleTimestamp = metaInfos["timestamp"] as? Double else {
            throw CCTParserError.invalidTimestamp(metaInfos)
        }
        let timestamp = Date(timeIntervalSince1970: doubleTimestamp)
        let simSlotID = metaInfos["simSlotID"] as? UInt8
        let cells = try sample.dropLast(1).map { try parseCell($0) }

        if cells.isEmpty {
            throw CCTParserError.noCells(sample)
        }

        guard var servingCell = cells.first(where: { $0.type == CCTCellType.serving})?.cell else {
            throw CCTParserError.noServingCell(sample)
        }

        servingCell.timestamp = timestamp
        servingCell.simSlotID = simSlotID

        return servingCell
    }

    private func parseCell(_ info: CellInfo) throws -> (cell: CCTCellProperties, type: CCTCellType) {
        // Location for symbols:
        // - Own sample collection using the tweak
        // - IPSW: /System/Library/Frameworks/CoreTelephony.framework/CoreTelephony (dyld_cache)
        // - https://github.com/nahum365/CellularInfo/blob/master/CellInfoView.m#L32

        let rat = info["CellRadioAccessTechnology"]
        guard let rat = rat as? String else {
            throw CCTParserError.missingRatOld(info)
        }

        var cell: CCTCellProperties
        switch rat {
        case "RadioAccessTechnologyGSM":
            cell = try parseGsm(info)
            cell.technology = .GSM
        case "RadioAccessTechnologyUMTS":
            cell = try parseUtms(info)
            cell.technology = .UMTS
        case "RadioAccessTechnologyUTRAN":
            // UMTS Terrestrial Radio Access Network
            // https://en.wikipedia.org/wiki/UMTS_Terrestrial_Radio_Access_Network
            cell = try parseUtms(info)
            cell.technology = .UMTS
        case "RadioAccessTechnologyCDMA1x":
            // https://en.wikipedia.org/wiki/CDMA2000
            cell = try parseCdma(info)
            cell.technology = .CDMA
        case "RadioAccessTechnologyCDMAEVDO":
            // CDMA2000 1x Evolution-Data Optimized
            cell = try parseCdma(info)
            cell.technology = .CDMA
        case "RadioAccessTechnologyCDMAHybrid":
            cell = try parseCdma(info)
            cell.technology = .CDMA
        case "RadioAccessTechnologyLTE":
            cell = try parseLte(info)
            cell.technology = .LTE
        case "RadioAccessTechnologyTDSCDMA":
            // Special version of UMTS WCDMA in China
            // https://www.electronics-notes.com/articles/connectivity/3g-umts/td-scdma.php
            cell = try parseUtms(info)
            cell.technology = .SCDMA
        case "RadioAccessTechnologyNR":
            cell = try parseNr(info)
            cell.technology = .NR
        default:
            throw CCTParserError.unknownRat(rat)
        }

        let cellType = info["CellType"]
        guard let cellType = cellType as? String else {
            throw CCTParserError.missingCellType(info)
        }
        guard let cellType = CCTCellType(rawValue: cellType) else {
            throw CCTParserError.unknownCellType(cellType)
        }

        cell.preciseTechnology = rat

        return (cell, cellType)
    }

    private func parseGsm(_ info: CellInfo) throws -> CCTCellProperties {
        var cell = CCTCellProperties()
        cell.technology = .GSM

        cell.mcc = info["MCC"] as? Int32 ?? 0
        cell.network = info["MNC"] as? Int32 ?? 0
        cell.area = info["LAC"] as? Int32 ?? 0
        cell.cellId = info["CellId"] as? Int64 ?? 0

        cell.frequency = info["ARFCN"] as? Int32 ?? 0
        cell.band = info["BandInfo"] as? Int32 ?? 0

        return cell
    }

    private func parseUtms(_ info: CellInfo) throws -> CCTCellProperties {
        var cell = CCTCellProperties()

        // UMTS has been phased out in many countries
        // https://de.wikipedia.org/wiki/Universal_Mobile_Telecommunications_System

        // Therefore this is just a guess and not tested but it should be the similar to GSM
        // https://en.wikipedia.org/wiki/Mobility_management#Location_area

        // With some data collected in Austria, we could confirm this
        // There's also the field "SCN" which could be an abbreviation for sub-channel number

        cell.mcc = info["MCC"] as? Int32 ?? 0
        cell.network = info["MNC"] as? Int32 ?? 0
        cell.area = info["LAC"] as? Int32 ?? 0
        cell.cellId = info["CellId"] as? Int64 ?? 0

        cell.frequency = info["UARFCN"] as? Int32 ?? 0
        cell.band = info["BandInfo"] as? Int32 ?? 0

        return cell
    }

    private func parseCdma(_ info: CellInfo) throws -> CCTCellProperties {
        // CDMA has been shutdown is most countries:
        // - https://www.verizon.com/about/news/3g-cdma-network-shut-date-set-december-31-2022
        // - https://www.digi.com/blog/post/2g-3g-4g-lte-network-shutdown-updates
        // - https://en.wikipedia.org/wiki/List_of_CDMA2000_networks

        // Sources:
        // https://wiki.opencellid.org/wiki/Public:CDMA
        // https://en.wikipedia.org/wiki/CDMA_subscriber_identity_module
        // https://github.com/nahum365/CellularInfo/blob/master/CellInfoView.m#L47
        // https://github.com/CellMapper/Map-BETA/issues/13
        // https://www.howardforums.com/showthread.php/1578315-Verizon-cellId-and-channel-number-questions?highlight=SID%3ANID%3ABID

        // Just a guess, not tested

        var cell = CCTCellProperties()

        cell.mcc = info["MCC"] as? Int32 ?? 0
        cell.network = info["SID"] as? Int32 ?? 0
        cell.area = info["PNOffset"] as? Int32 ?? 0
        cell.cellId = info["BaseStationId"] as? Int64 ?? 0

        cell.band = info["ChannelNumber"] as? Int32 ?? 0
        cell.frequency = info["BandClass"] as? Int32 ?? 0

        return cell
    }

    private func parseLte(_ info: CellInfo) throws -> CCTCellProperties {
        var cell = CCTCellProperties()

        cell.mcc = info["MCC"] as? Int32 ?? 0
        cell.network = info["MNC"] as? Int32 ?? 0
        cell.area = info["TAC"] as? Int32 ?? 0
        // See: https://dev.seemoo.tu-darmstadt.de/apple/cell-guard/-/issues/98
        cell.cellId = info["CellId"] as? Int64 ?? 0

        // Although the correct name is EARFCN, here Apple still uses the name UARFCN from UMTS
        // See:
        // - https://en.wikipedia.org/wiki/UMTS#UARFCN
        // - https://de.wikipedia.org/wiki/UTRA_Absolute_Radio_Frequency_Channel_Number
        cell.frequency = info["UARFCN"] as? Int32 ?? 0
        cell.band = info["BandInfo"] as? Int32 ?? 0
        cell.bandwidth = info["Bandwidth"] as? Int32 ?? 0
        cell.physicalCellId = info["PID"] as? Int32 ?? 0

        // If a deployment type > 0 is set, the cell supports 5G NSA
        // SA+NSA = 3
        cell.deploymentType = info["DeploymentType"] as? Int32 ?? 0

        // kCTCellMonitorDeploymentType = 3 -> 5G NSA
        // From the field test mode (*3001#12345#*) on iOS 16
        // What do the other deployment types could refer to?
        // https://www.howardforums.com/showthread.php/1920794-5G-Nationwide-Speed-Test-Thread/page17
        // Apparently independent of the value if the field field is set, the cell supports 5G NSA
        // But we're only using it, if a neighboring NR cell appears in the data

        // Throughput
        // CSGIndication = 0 -> https://www.sharetechnote.com/html/Handbook_LTE_CSG_OAM.html
        // CsgId -> Closed Subscriber Group
        // PMax -> Maximum output power of the basestation

        return cell
    }

    private func parseNr(_ info: CellInfo) throws -> CCTCellProperties {
        var cell = CCTCellProperties()

        // Just a guess, based on the strings of CommCenter (extracted with Ghidra)

        cell.mcc = info["MCC"] as? Int32 ?? 0
        cell.network = info["MNC"] as? Int32 ?? 0
        cell.area = info["TAC"] as? Int32 ?? 0
        cell.cellId = info["CellId"] as? Int64 ?? 0

        // Usually the frequency is called ARFCN, but Apple apparently appended a prefix NR to it
        cell.frequency = info["NRARFCN"] as? Int32 ?? 0
        cell.band = info["BandInfo"] as? Int32 ?? 0
        cell.bandwidth = info["Bandwidth"] as? Int32 ?? 0
        cell.physicalCellId = info["PID"] as? Int32 ?? 0

        return cell
    }
}
