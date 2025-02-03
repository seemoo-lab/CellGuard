//
//  CCTParser.swift
//  CellGuard
//
//  Created by Lukas Arnold on 01.01.23.
//

import Foundation
import CoreData
import BinarySwift

enum CCTParserError: Error {
    case emptySample(CellSample)
    case noCells(CellSample)
    case noServingCell(CellSample)
    case invalidTimestamp(CellInfo)
    case missingRAT(Data)
    case missingRATOld(CellInfo)
    case unknownRAT(String)
    case notImplementedRAT(String)
    case missingCellType(CellInfo)
    case unknownCellType(String)
    case invalidQMIService
    case invalidQMIMessage
    case invalidQMIDirection
    case noQMILTECellInformation(ParsedQMIPacket)
    case unexpectedTLVLength
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
    var physicalCellId: Int32?
    
    var technology: ALSTechnology?
    var preciseTechnology: String?
    var frequency: Int32?
    var band: Int32?
    var bandwidth: Int32?
    var neighborRadio: String?
    var deploymentType: Int32?
    
    var timestamp: Date?
    
    var json: String?
    var rawQMI: Data?
    
    func applyTo(tweakCell: CellTweak) {
        tweakCell.country = self.mcc ?? 0
        tweakCell.network = self.network ?? 0
        tweakCell.area = self.area ?? 0
        tweakCell.cell = self.cellId ?? 0
        
        tweakCell.technology = (self.technology ?? .LTE).rawValue
        tweakCell.preciseTechnology = self.preciseTechnology
        
        tweakCell.frequency = self.frequency ?? 0
        tweakCell.band = self.band ?? 0
        tweakCell.bandwidth = self.bandwidth ?? 0
        tweakCell.physicalCell = self.physicalCellId ?? 0
        tweakCell.neighborTechnology = neighborRadio
        
        tweakCell.collected = self.timestamp
        tweakCell.json = self.json
        tweakCell.rawQMI = self.rawQMI
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
            throw CCTParserError.missingRATOld(info)
        }
        
        var cell: CCTCellProperties
        switch (rat) {
        case "RadioAccessTechnologyGSM":
            cell = try parseGSM(info)
            cell.technology = .GSM
        case "RadioAccessTechnologyUMTS":
            cell = try parseUTMS(info)
            cell.technology = .UMTS
        case "RadioAccessTechnologyUTRAN":
            // UMTS Terrestrial Radio Access Network
            // https://en.wikipedia.org/wiki/UMTS_Terrestrial_Radio_Access_Network
            cell = try parseUTMS(info)
            cell.technology = .UMTS
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
        
        cell.frequency = info["ARFCN"] as? Int32 ?? 0
        cell.band = info["BandInfo"] as? Int32 ?? 0
        
        return cell
    }
    
    private func parseUTMS(_ info: CellInfo) throws -> CCTCellProperties {
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
    
    private func parseCDMA(_ info: CellInfo) throws -> CCTCellProperties {
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
    
    
    private func parseLTE(_ info: CellInfo) throws -> CCTCellProperties {
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
    
    private func parseNR(_ info: CellInfo) throws -> CCTCellProperties {
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
    
    func parseQMICell(_ data: Data, timestamp: Date) throws -> [CCTCellProperties] {
        // Location for symbols:
        // - Own sample collection using the tweak
        // - IPSW: /System/Library/Frameworks/CoreTelephony.framework/CoreTelephony (dyld_cache)
        // - https://github.com/nahum365/CellularInfo/blob/master/CellInfoView.m#L32
        
        let parsedPacket = try ParsedQMIPacket(nsData: data)
        if parsedPacket.qmuxHeader.serviceId != PacketConstants.qmiCellInfoService {
            throw CCTParserError.invalidQMIService
        }
        if parsedPacket.messageHeader.messageId != PacketConstants.qmiCellInfoMessage {
            throw CCTParserError.invalidQMIMessage
        }
        if !parsedPacket.transactionHeader.indication && !parsedPacket.transactionHeader.response {
            throw CCTParserError.invalidQMIDirection
        }
        
        var cells: [CCTCellProperties] = []
        for technology in PacketConstants.qmiCellInfoTechnologies {
            guard let tlvType = PacketConstants.qmiTLVTypes[technology],
                  let tlv = parsedPacket.findTlvValue(type: tlvType) else {
                continue
            }
            
            var cell: CCTCellProperties?
            switch technology {
            case .cdma1x, .cdmaEvdo:
                // https://en.wikipedia.org/wiki/CDMA2000
                // CDMA2000 1x Evolution-Data Optimized
                cell = try? parseCDMA(tlv, version: technology)
            case .umts, .tdscdma:
                // Special version of UMTS WCDMA in China
                // https://www.electronics-notes.com/articles/connectivity/3g-umts/td-scdma.php
                cell = try? parseUTMS(tlv, version: technology)
            case .gsm:
                cell = try? parseGSM(tlv)
            case .lteV1, .lteV2, .lteV3, .lteV4:
                cell = try? parseLTE(tlv, version: technology)
            case .nrV2, .nrV3:
                cell = try? parseNR(tlv, version: technology)
            }
            
            if var cell = cell {
                cell.preciseTechnology = technology.rawValue
                cell.timestamp = timestamp
                cell.rawQMI = data
                
                // We only want to store at most one cell for each ALSTechnology.
                if let index = cells.firstIndex(where: { $0.technology == cell.technology }) {
                    cells[index] = cell
                } else {
                    cells.append(cell)
                }
            }
        }
        
        if cells.isEmpty {
            throw CCTParserError.missingRAT(data)
        }

        return cells
    }
    
    private func parseGSM(_ tlv: QMITLV) throws -> CCTCellProperties {
        var cell = CCTCellProperties()
        cell.technology = .GSM
        
        if tlv.length != 22 {
            throw CCTParserError.unexpectedTLVLength
        }
        
        // See: https://dev.seemoo.tu-darmstadt.de/apple/iphone-qmi-wireshark/-/blob/main/dissector/qmi_dissector_template.lua
        let data = BinaryData(data: tlv.data, bigEndian: false)
        let _: UInt8 = try data.get(0) // array_length
        let _: UInt16 = try data.get(1) // index
        cell.mcc = Int32((try? data.get(3) as UInt16) ?? 0)
        cell.network = Int32((try? data.get(5) as UInt16) ?? 0)
        cell.band = Int32((try? data.get(7) as UInt8) ?? 0) + 1 // The offset by one provides alignment with the iOS libraries
        cell.area = Int32((try? data.get(8) as UInt16) ?? 0)
        cell.cellId = Int64((try? data.get(10) as UInt16) ?? 0)
        cell.frequency = Int32((try? data.get(12) as UInt16) ?? 0)
        let _: UInt32 = try data.get(14) // latitude
        let _: UInt32 = try data.get(18) // longitude
        
        return cell
    }
    
    private func parseUTMS(_ tlv: QMITLV, version: ALSTechnologyVersion) throws -> CCTCellProperties {
        var cell = CCTCellProperties()
        cell.technology = .UMTS
        
        // UMTS has been phased out in many countries
        // https://de.wikipedia.org/wiki/Universal_Mobile_Telecommunications_System
        
        // Therefore this is just a guess and not tested but it should be the similar to GSM
        // https://en.wikipedia.org/wiki/Mobility_management#Location_area
        
        // With some data collected in Austria, we could confirm this
        // There's also the field "SCN" which could be an abbreviation for sub-channel number
        
        
        if tlv.length != 26 {
            throw CCTParserError.unexpectedTLVLength
        }
        
        // See: https://dev.seemoo.tu-darmstadt.de/apple/iphone-qmi-wireshark/-/blob/main/dissector/qmi_dissector_template.lua
        let data = BinaryData(data: tlv.data, bigEndian: false)
        let _: UInt8 = try data.get(0) // array_length
        let _: UInt16 = try data.get(1) // index
        cell.mcc = Int32((try? data.get(3) as UInt16) ?? 0)
        cell.network = Int32((try? data.get(5) as UInt16) ?? 0)
        cell.band = Int32((try? data.get(7) as UInt8) ?? 0) + 1 // The offset by one provides alignment with the iOS libraries
        cell.area = Int32((try? data.get(8) as UInt16) ?? 0)
        cell.cellId = Int64((try? data.get(10) as UInt32) ?? 0)
        cell.frequency = Int32((try? data.get(14) as UInt16) ?? 0)
        let _: UInt16 = try data.get(16) // cellParameter
        let _: UInt32 = try data.get(18) // latitude
        let _: UInt32 = try data.get(22) // longitude
        
        return cell
    }
    
    private func parseCDMA(_ tlv: QMITLV, version: ALSTechnologyVersion) throws -> CCTCellProperties {
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
        cell.technology = .CDMA
        
        if (version == .cdma1x && tlv.length != 30) || (version == .cdmaEvdo && tlv.length != 34) {
            throw CCTParserError.unexpectedTLVLength
        }
        
        // See: https://dev.seemoo.tu-darmstadt.de/apple/iphone-qmi-wireshark/-/blob/main/dissector/qmi_dissector_template.lua
        let data = BinaryData(data: tlv.data, bigEndian: false)
        let _: UInt8 = try data.get(0) // array_length
        let _: UInt16 = try data.get(1) // index
        cell.mcc = Int32((try? data.get(3) as UInt16) ?? 0)
        
        if version == .cdma1x {
            let _ = Int32((try? data.get(5) as UInt16) ?? 0) // mnc
            cell.frequency = Int32((try? data.get(7) as UInt8) ?? 0)
            cell.band = Int32((try? data.get(8) as UInt16) ?? 0) + 1 // The offset by one provides alignment with the iOS libraries
            cell.network = Int32((try? data.get(10) as UInt16) ?? 0)
            let _: UInt16 = try data.get(12) // nid
            cell.cellId = Int64((try? data.get(14) as UInt16) ?? 0)
            let _: UInt32 = try data.get(16) // latitude
            let _: UInt32 = try data.get(20) // longitude
            let _: UInt16 = try data.get(24) // zoneID
            cell.area = Int32((try? data.get(26) as UInt16) ?? 0)
            let _: UInt8 = try data.get(28) // ltmOffset
            let _: UInt8 = try data.get(29) // dayLightSavings
        } else if version == .cdmaEvdo {
            cell.frequency = Int32((try? data.get(5) as UInt8) ?? 0)
            cell.band = Int32((try? data.get(6) as UInt16) ?? 0)
            let _ = try data.getUTF8(8, length: 16) // sectorID
            let _: UInt32 = try data.get(24) // latitude
            let _: UInt32 = try data.get(28) // longitude
            cell.area = Int32((try? data.get(32) as UInt16) ?? 0)
        }
        
        return cell
    }
    
    
    private func parseLTE(_ tlv: QMITLV, version: ALSTechnologyVersion) throws -> CCTCellProperties {
        var cell = CCTCellProperties()
        cell.technology = .LTE
        
        // We currently do not have support for array_length != 1 as then a multiple of the payload length would be transmitted.
        // However, we have not seen such CellInformation messages so far.
        if (version == .lteV1 && tlv.length != 27) || (version == .lteV2 && tlv.length != 29) ||
            (version == .lteV3 && tlv.length != 32) || (version == .lteV4 && tlv.length != 49) {
            throw CCTParserError.unexpectedTLVLength
        }
        
        // See: https://dev.seemoo.tu-darmstadt.de/apple/iphone-qmi-wireshark/-/blob/main/dissector/qmi_dissector_template.lua
        var offset = 0
        let data = BinaryData(data: tlv.data, bigEndian: false)
        
        let _: UInt8 = try data.get(0) // array_length
        let _: UInt16 = try data.get(1) // index
        
        cell.mcc = Int32((try? data.get(3) as UInt16) ?? 0)
        cell.network = Int32((try? data.get(5) as UInt16) ?? 0)
        cell.band = Int32((try? data.get(7) as UInt8) ?? 0) + 1 // The offset by one provides alignment with the iOS libraries
        
        offset = 8
        if version == .lteV1 || version == .lteV2 {
            cell.area = Int32((try? data.get(8) as UInt16) ?? 0)
            offset += 2
        } else if version == .lteV3 || version == .lteV4 {
            cell.area = Int32((try? data.get(8) as UInt32) ?? 0)
            offset += 4
        }
        
        // See: https://dev.seemoo.tu-darmstadt.de/apple/cell-guard/-/issues/98
        cell.cellId = Int64((try? data.get(offset) as UInt32) ?? 0)
        offset += 4
        
        if version == .lteV1 {
            cell.frequency = Int32((try? data.get(offset) as UInt16) ?? 0)
            offset += 2
        } else if version == .lteV2 || version == .lteV3 || version == .lteV4 {
            // With a max value of 262143, the conversion causes no overflow.
            cell.frequency = Int32((try? data.get(offset) as UInt32) ?? 0)
            offset += 4
        }
        
        cell.physicalCellId = Int32((try? data.get(offset) as UInt16) ?? 0)
        offset += 2
        let _: UInt32 = try data.get(offset) // latitude
        offset += 4
        let _: UInt32 = try data.get(offset) // longitude
        offset += 4
        cell.bandwidth = Int32((try? data.get(offset) as UInt8) ?? 0)
        offset += 1
        
        if version == .lteV3 || version == .lteV4 {
            // kCTCellMonitorDeploymentType = 3 -> 5G NSA
            // From the field test mode (*3001#12345#*) on iOS 16
            // What do the other deployment types could refer to?
            // https://www.howardforums.com/showthread.php/1920794-5G-Nationwide-Speed-Test-Thread/page17
            // Apparently independent of the value if the field field is set, the cell supports 5G NSA
            // But we're only using it, if a neighboring NR cell appears in the data
            
            // If a deployment type > 0 is set, the cell supports 5G NSA
            // SA+NSA = 3
            cell.deploymentType = Int32((try? data.get(offset) as UInt8) ?? 0)
            offset += 1
        }
        
        if version == .lteV4 {
            // Throughput
            let _: UInt32 = try data.get(offset)
            offset += 4
            // CSGIndication = 0 -> https://www.sharetechnote.com/html/Handbook_LTE_CSG_OAM.html
            let _: UInt8 = try data.get(offset)
            offset += 1
            // CsgId -> Closed Subscriber Group
            let _: UInt32 = try data.get(offset)
            offset += 4
            // PMax -> Maximum output power of the basestation
            let _: UInt16 = try data.get(offset)
            offset += 2
            // Two unknown UInt32 values are left
        }
        
        return cell
    }
    
    
    private func parseNR(_ tlv: QMITLV, version: ALSTechnologyVersion) throws -> CCTCellProperties {
        var cell = CCTCellProperties()
        cell.technology = .NR
        
        if (version == .nrV2 && tlv.length != 42) || (version == .nrV3 && tlv.length != 57) {
            throw CCTParserError.unexpectedTLVLength
        }
        
        // See: https://dev.seemoo.tu-darmstadt.de/apple/iphone-qmi-wireshark/-/blob/main/dissector/qmi_dissector_template.lua
        let data = BinaryData(data: tlv.data, bigEndian: false)
        let _: UInt8 = try data.get(0) // array_length
        let _: UInt16 = try data.get(1) // index
        cell.mcc = Int32((try? data.get(3) as UInt16) ?? 0)
        cell.network = Int32((try? data.get(5) as UInt16) ?? 0)
        cell.band = Int32((try? data.get(7) as UInt16) ?? 0) + 1 // The offset by one provides alignment with the iOS libraries
        // According to the specification, the TAC uses just 24 bit. Therefore, this conversion causes no overflow.
        cell.area = Int32((try? data.get(9) as UInt32) ?? 0)
        // With a max value of 3279165, this conversion causes no overflow.
        cell.cellId = Int64((try? data.get(13) as UInt64) ?? 0)
        cell.frequency = Int32((try? data.get(21) as UInt32) ?? 0)
        cell.physicalCellId = Int32((try? data.get(25) as UInt16) ?? 0)
        let _: UInt32 = try data.get(27) // latitude
        let _: UInt32 = try data.get(31) // longitude
        cell.bandwidth = Int32((try? data.get(35) as UInt16) ?? 0)
        let _: UInt8 = try data.get(37) // scs
        let _: UInt32 = try data.get(38) // gscn
        
        if version == .nrV3 {
            let _: UInt8 = try data.get(42) // bwpSupport
            let _: UInt32 = try data.get(43) // throughput
            let _: UInt16 = try data.get(47) // pMax
            // Two unknown UInt32 values are left
        }
        
        return cell
    }
    
}
