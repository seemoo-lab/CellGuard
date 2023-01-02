//
//  CCTParser.swift
//  CellGuard
//
//  Created by Lukas Arnold on 01.01.23.
//

import Foundation

/*
(
    {
        kCTCellMonitorBandInfo = 20;
        kCTCellMonitorBandwidth = 50;
        kCTCellMonitorCellId = 12941827;
        kCTCellMonitorCellRadioAccessTechnology = kCTCellMonitorRadioAccessTechnologyLTE;
        kCTCellMonitorCellType = kCTCellMonitorCellTypeServing;
        kCTCellMonitorDeploymentType = 5;
        kCTCellMonitorMCC = 262;
        kCTCellMonitorMNC = 2;
        kCTCellMonitorPID = 33;
        kCTCellMonitorRSRP = 0;
        kCTCellMonitorRSRQ = 0;
        kCTCellMonitorSectorLat = 0;
        kCTCellMonitorSectorLong = 0;
        kCTCellMonitorTAC = 45711;
        kCTCellMonitorUARFCN = 6300;
    },
    {
        kCTCellMonitorCellRadioAccessTechnology = kCTCellMonitorRadioAccessTechnologyNR;
        kCTCellMonitorCellType = kCTCellMonitorCellTypeNeighbor;
        kCTCellMonitorIsSA = 0;
        kCTCellMonitorNRARFCN = 372750;
        kCTCellMonitorPCI = 133;
        kCTCellMonitorSCS = 0;
    }
)
    // https://github.com/nahum365/CellularInfo/blob/master/CellInfoView.m#L32
    // Symbols from /System/Library/Frameworks/CoreTelephony.framework/CoreTelephony (dyld_cache)

*/

enum CCTParserError: Error {
    case emptySample(CellSample)
    case noCells(CellSample)
    case noServingCell(CellSample)
    case invalidTimestamp(CellInfo)
    case missingRAT(CellInfo)
    case unknownRAT(String)
    case notImplementedRAT(String)
    case missingCellType(CellInfo)
    case unknownCellType(String)
}

enum CCTCellType: String {
    case Serving = "CellTypeServing"
    case Neighbour = "CellTypeNeighbor"
    case Monitor = "CellTypeMonitor"
    case Detected = "CellTypeDetected"
}

struct CCTParser {
    
    private let jsonEncoder = JSONEncoder()
    
    func parse(_ sample: CellSample) throws -> Cell {
        if sample.isEmpty {
            throw CCTParserError.emptySample(sample)
        }
        
        guard let doubleTimestamp = sample.last?["timestamp"] as? Double else {
            throw CCTParserError.invalidTimestamp(sample.last!)
        }
        let timestamp = Date(timeIntervalSince1970: doubleTimestamp)
        let cells = try sample.dropLast(1).map() { try parseCell($0) }
        
        if cells.isEmpty {
            throw CCTParserError.noCells(sample)
        }
        
        let servingCell = cells.first(where: { $0.type == CCTCellType.Serving})?.cell
        let neighborCell = cells.first(where: { $0.type == CCTCellType.Neighbour})?.cell
        
        guard let servingCell = servingCell else {
            throw CCTParserError.noServingCell(sample)
        }
        
        if let neighborCell = neighborCell {
            servingCell.neighbourRadio = neighborCell.radio
        }
        
        servingCell.timestamp = timestamp
        // TODO: Find a better solution for JSON - https://stackoverflow.com/a/68886622
        // servingCell.json = String(data: try jsonEncoder.encode(sample), encoding: .utf8)
        return servingCell
    }
    
    private func parseCell(_ info: CellInfo) throws -> (cell: Cell, type: CCTCellType) {
        // Location for symbols:
        // - Own sample collection using the tweak
        // - IPSW: /System/Library/Frameworks/CoreTelephony.framework/CoreTelephony (dyld_cache)
        // - https://github.com/nahum365/CellularInfo/blob/master/CellInfoView.m#L32
        
        let rat = info["RadioAccessTechnology"]
        guard let rat = rat as? String else {
            throw CCTParserError.missingRAT(info)
        }
        
        let cell: Cell
        switch (rat) {
        case "RadioAccessTechnologyGSM":
            cell = try parseGSM(info)
        case "RadioAccessTechnologyUMTS":
            // UMTS has been phased out in many countries
            // https://de.wikipedia.org/wiki/Universal_Mobile_Telecommunications_System
            cell = try parseUTMS(info)
        case "RadioAccessTechnologyUTRAN":
            // UMTS Terrestrial Radio Access Network
            // https://en.wikipedia.org/wiki/UMTS_Terrestrial_Radio_Access_Network
            cell = try parseUTMS(info)
        case "RadioAccessTechnologyCDMA1x":
            // https://en.wikipedia.org/wiki/CDMA2000
            // There are also only a few CDMA1x networks remaining
            // https://en.wikipedia.org/wiki/List_of_CDMA2000_networks
            cell = try parseCDMA1x(info)
        case "RadioAccessTechnologyCDMAEVDO":
            // CDMA2000 1x Evolution-Data Optimized
            // Same as above
            cell = try parseCDMAevdo(info)
        case "RadioAccessTechnologyCDMAHybrid":
            cell = try parseCDMAevdo(info)
        case "RadioAccessTechnologyLTE":
            cell = try parseLTE(info)
        case "RadioAccessTechnologyTDSCDMA":
            // https://www.electronics-notes.com/articles/connectivity/3g-umts/td-scdma.php
            cell = try parseUTMS(info)
        case "RadioAccessTechnologyNR":
            cell = try parseNR(info)
        default:
            throw CCTParserError.unknownRAT(rat)
        }
        
        let cellType = info["CellType"]
        guard let cellType = cellType as? String else {
            throw CCTParserError.missingCellType(info)
        }
        guard let cellType = CCTCellType(rawValue: cellType) else {
            throw CCTParserError.unknownCellType(cellType)
        }
         
        cell.radio = rat
        
        return (cell, cellType)
    }
    
    private func parseGSM(_ info: CellInfo) throws -> Cell {
        let cell = Cell()
        
        cell.mcc = info["MCC"] as? Int32 ?? 0
        cell.network = info["MNC"] as? Int32 ?? 0
        cell.area = info["LAC"] as? Int32 ?? 0
        cell.cellId = info["CellId"] as? Int64 ?? 0
        
        // We're using ARFCN here as BandInfo was always 0
        cell.band = info["ARFCN"] as? Int32 ?? 0
        
        return cell
    }
    
    private func parseUTMS(_ info: CellInfo) throws -> Cell {
        let cell = Cell()
        
        // Just a guess not tested, but should be the same according Wikipedia
        // https://en.wikipedia.org/wiki/Mobility_management#Location_area
        
        cell.mcc = info["MCC"] as? Int32 ?? 0
        cell.network = info["MNC"] as? Int32 ?? 0
        cell.area = info["LAC"] as? Int32 ?? 0
        cell.cellId = info["CellId"] as? Int64 ?? 0
        
        cell.band = info["BandInfo"] as? Int32 ?? 0
        
        return cell
    }
    
    private func parseCDMA1x(_ info: CellInfo) throws -> Cell {
        // https://github.com/CellMapper/Map-BETA/issues/13
        // https://en.wikipedia.org/wiki/CDMA_subscriber_identity_module
        // https://wiki.opencellid.org/wiki/Public:CDMA
        let cell = Cell()
        
        cell.mcc = 0
        cell.network = info["SID"] as? Int32 ?? 0
        cell.area = 0
        cell.cellId = info["BaseStationId"] as? Int64 ?? 0
        
        cell.band = info["BandClass"] as? Int32 ?? 0
        
        return cell
    }
    
    private func parseCDMAevdo(_ info: CellInfo) throws -> Cell {
        // https://github.com/nahum365/CellularInfo/blob/master/CellInfoView.m#L111
        // https://www.howardforums.com/showthread.php/1578315-Verizon-cellId-and-channel-number-questions?highlight=SID%3ANID%3ABID
        let cell = Cell()
        
        cell.mcc = info["MCC"] as? Int32 ?? 0
        cell.network = info["SID"] as? Int32 ?? 0
        cell.area = info["PNOffset"] as? Int32 ?? 0
        cell.cellId = info["BaseStationId"] as? Int64 ?? 0
        
        cell.band = info["BandClass"] as? Int32 ?? 0
        
        return cell
    }
    
    
    private func parseLTE(_ info: CellInfo) throws -> Cell {
        let cell = Cell()
        
        cell.mcc = info["MCC"] as? Int32 ?? 0
        cell.network = info["MNC"] as? Int32 ?? 0
        cell.area = info["TAC"] as? Int32 ?? 0
        cell.cellId = info["CellId"] as? Int64 ?? 0
        
        cell.band = info["BandInfo"] as? Int32 ?? 0
        
        return cell
    }
    
    private func parseNR(_ info: CellInfo) throws -> Cell {
        let cell = Cell()
        
        // Just a guess
        
        cell.mcc = info["MCC"] as? Int32 ?? 0
        cell.network = info["MNC"] as? Int32 ?? 0
        cell.area = info["TAC"] as? Int32 ?? 0
        cell.cellId = info["CellId"] as? Int64 ?? 0
        
        cell.band = info["BandInfo"] as? Int32 ?? 0

        return cell
    }
    
}
