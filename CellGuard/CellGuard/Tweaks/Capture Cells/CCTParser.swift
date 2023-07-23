//
//  CCTParser.swift
//  CellGuard
//
//  Created by Lukas Arnold on 01.01.23.
//

import Foundation
import CoreData

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
    case Neighbor = "CellTypeNeighbor"
    case Monitor = "CellTypeMonitor"
    case Detected = "CellTypeDetected"
}

/// A structure similar to the model "Cell".
struct CCTCellProperties {
    
    var mcc: Int32?
    var network: Int32?
    var area: Int32?
    var cellId: Int64?
    
    var technology: ALSTechnology?
    var preciseTechnology: String?
    var frequency: Int32?
    var neighborRadio: String?
    
    var timestamp: Date?
    
    var json: String?
    
    func applyTo(tweakCell: TweakCell) {
        tweakCell.country = self.mcc ?? 0
        tweakCell.network = self.network ?? 0
        tweakCell.area = self.area ?? 0
        tweakCell.cell = self.cellId ?? 0
        
        tweakCell.technology = (self.technology ?? .LTE).rawValue
        tweakCell.preciseTechnology = self.preciseTechnology
        
        tweakCell.frequency = self.frequency ?? 0
        tweakCell.neighborTechnology = neighborRadio
        
        tweakCell.collected = self.timestamp
        tweakCell.json = self.json
    }

}

struct CCTParser {
    
    func parse(_ sample: CellSample) throws -> CCTCellProperties {
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
        let neighborCell = cells.first(where: { $0.type == CCTCellType.Neighbor})?.cell
        
        guard var servingCell = servingCell else {
            throw CCTParserError.noServingCell(sample)
        }
        
        if let neighborCell = neighborCell {
            servingCell.neighborRadio = neighborCell.preciseTechnology
        }
        
        // We're using JSONSerialization because the JSONDecoder requires specific type information that we can't provide
        servingCell.json = String(data: try JSONSerialization.data(withJSONObject: sample), encoding: .utf8)
        servingCell.timestamp = timestamp
        
        return servingCell
    }
    
    private func parseCell(_ info: CellInfo) throws -> (cell: CCTCellProperties, type: CCTCellType) {
        // Location for symbols:
        // - Own sample collection using the tweak
        // - IPSW: /System/Library/Frameworks/CoreTelephony.framework/CoreTelephony (dyld_cache)
        // - https://github.com/nahum365/CellularInfo/blob/master/CellInfoView.m#L32
        
        let rat = info["CellRadioAccessTechnology"]
        guard let rat = rat as? String else {
            throw CCTParserError.missingRAT(info)
        }
        
        var cell: CCTCellProperties
        switch (rat) {
        case "RadioAccessTechnologyGSM":
            cell = try parseGSM(info)
            cell.technology = .GSM
        case "RadioAccessTechnologyUMTS":
            cell = try parseUTMS(info)
            cell.technology = .LTE
        case "RadioAccessTechnologyUTRAN":
            // UMTS Terrestrial Radio Access Network
            // https://en.wikipedia.org/wiki/UMTS_Terrestrial_Radio_Access_Network
            cell = try parseUTMS(info)
            cell.technology = .LTE
        case "RadioAccessTechnologyCDMA1x":
            // https://en.wikipedia.org/wiki/CDMA2000
            cell = try parseCDMA(info)
            cell.technology = .CDMA
        case "RadioAccessTechnologyCDMAEVDO":
            // CDMA2000 1x Evolution-Data Optimized
            cell = try parseCDMA(info)
            cell.technology = .CDMA
        case "RadioAccessTechnologyCDMAHybrid":
            cell = try parseCDMA(info)
            cell.technology = .CDMA
        case "RadioAccessTechnologyLTE":
            cell = try parseLTE(info)
            cell.technology = .LTE
        case "RadioAccessTechnologyTDSCDMA":
            // Special version of UMTS WCDMA in China
            // https://www.electronics-notes.com/articles/connectivity/3g-umts/td-scdma.php
            cell = try parseUTMS(info)
            cell.technology = .SCDMA
        case "RadioAccessTechnologyNR":
            cell = try parseNR(info)
            cell.technology = .NR
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
        
        cell.preciseTechnology = rat
        
        return (cell, cellType)
    }
    
    private func parseGSM(_ info: CellInfo) throws -> CCTCellProperties {
        var cell = CCTCellProperties()
        cell.technology = .GSM
        
        cell.mcc = info["MCC"] as? Int32 ?? 0
        cell.network = info["MNC"] as? Int32 ?? 0
        cell.area = info["LAC"] as? Int32 ?? 0
        cell.cellId = info["CellId"] as? Int64 ?? 0
        
        // We're using ARFCN here as BandInfo is always 0
        cell.frequency = info["ARFCN"] as? Int32 ?? 0
        
        return cell
    }
    
    private func parseUTMS(_ info: CellInfo) throws -> CCTCellProperties {
        var cell = CCTCellProperties()
        
        // UMTS has been phased out in many countries
        // https://de.wikipedia.org/wiki/Universal_Mobile_Telecommunications_System
        
        // Therefore this is just a guess and not tested but it should be the similar to GSM
        // https://en.wikipedia.org/wiki/Mobility_management#Location_area
        
        cell.mcc = info["MCC"] as? Int32 ?? 0
        cell.network = info["MNC"] as? Int32 ?? 0
        cell.area = info["LAC"] as? Int32 ?? 0
        cell.cellId = info["CellId"] as? Int64 ?? 0
        
        cell.frequency = info["BandInfo"] as? Int32 ?? 0
        
        return cell
    }
    
    private func parseCDMA(_ info: CellInfo) throws -> CCTCellProperties {
        // CDMA has been shutdown is most conutries:
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
        
        cell.frequency = info["BandClass"] as? Int32 ?? 0
        
        return cell
    }
    
    
    private func parseLTE(_ info: CellInfo) throws -> CCTCellProperties {
        var cell = CCTCellProperties()
        
        cell.mcc = info["MCC"] as? Int32 ?? 0
        cell.network = info["MNC"] as? Int32 ?? 0
        cell.area = info["TAC"] as? Int32 ?? 0
        cell.cellId = info["CellId"] as? Int64 ?? 0
        
        cell.frequency = info["BandInfo"] as? Int32 ?? 0
        
        return cell
    }
    
    private func parseNR(_ info: CellInfo) throws -> CCTCellProperties {
        var cell = CCTCellProperties()
        
        // Just a guess
        
        cell.mcc = info["MCC"] as? Int32 ?? 0
        cell.network = info["MNC"] as? Int32 ?? 0
        cell.area = info["TAC"] as? Int32 ?? 0
        cell.cellId = info["CellId"] as? Int64 ?? 0
        
        cell.frequency = info["BandInfo"] as? Int32 ?? 0

        return cell
    }
    
}
