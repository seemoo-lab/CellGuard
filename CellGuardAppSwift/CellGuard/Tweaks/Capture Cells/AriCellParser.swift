//
//  AriCellParser.swift
//  CellGuard
//
//  Created by mp on 01.04.25.
//

import Foundation
import BinarySwift

extension CCTParser {
    
    func parseAriCell(_ data: Data, timestamp: Date) throws -> [CCTCellProperties] {
        // Source: https://github.com/seemoo-lab/aristoteles/blob/master/types/structure/libari_dylib.lua
        
        let parsedPacket = try ParsedARIPacket(data: data)

        if parsedPacket.header.group != PacketConstants.ariCellInfoGroup {
            throw CCTParserError.invalidAriGroup
        }
        if !PacketConstants.ariCellInfoTypes.contains(parsedPacket.header.type) {
            throw CCTParserError.invalidAriMessage
        }

        var cells: [CCTCellProperties] = []
        for technology in PacketConstants.ariCellInfoTechnologies {
            let ariKey = ARIKey(type: parsedPacket.header.type, technology: technology)
            guard let tlvType = PacketConstants.ariCellInfoTLVTypes[ariKey] else {
                continue
            }
            guard let tlv = parsedPacket.findTlvValue(type: tlvType) else {
                continue
            }
            if tlv.hasEmptyData() {
                continue
            }

            var cell: CCTCellProperties?
            switch technology {
            case .cdma1x, .cdmaEvdo:
                cell = try? parseCdmaAri(tlv, version: technology)
            case .umts, .tdscdma:
                cell = try? parseUmtsAri(tlv, version: technology)
            case .gsm:
                cell = try? parseGsmAri(tlv)
            case .lte, .lteV1T, .lteR15, .lteR15V2:
                cell = try? parseLteAri(tlv, version: technology)
            case .nr, .nrV2:
                cell = try? parseNrAri(tlv, version: technology)
            default:
                throw CCTParserError.unknownRat(technology.rawValue)
            }
         
            if var cell = cell,
               !cell.isMissingKeyProperties() {
                cell.preciseTechnology = technology.rawValue
                cell.timestamp = timestamp
                
                // We keep only the most recent cell technology info version, e.g. we use the `lteR15` cell infos, if available, instead of the
                // `.lteV1T`, or `lte` cell infos. The order is defined by the PacketConstants.ariCellInfoTechnologies.
                if let index = cells.firstIndex(where: { $0.technology == cell.technology }) {
                    cells[index] = cell
                } else {
                    cells.append(cell)
                }
            }
        }

        if cells.isEmpty {
            throw CCTParserError.missingRat(parsedPacket)
        }

        return cells
    }
    
    private func parseGsmAri(_ tlv: AriTlv) throws -> CCTCellProperties {
        var cell = CCTCellProperties()
        cell.technology = .GSM
        
        if tlv.length != 24 {
            throw CCTParserError.unexpectedTlvLength
        }
        
        let data = BinaryData(data: tlv.data, bigEndian: false)
        let _: UInt16 = try data.get(0) // index
        cell.mcc = Int32((try? data.get(2) as UInt16) ?? 0)
        cell.network = Int32((try? data.get(4) as UInt16) ?? 0)
        cell.band = Int32((try? data.get(6) as UInt16) ?? 0)
        cell.area = Int32((try? data.get(8) as UInt16) ?? 0)
        cell.cellId = Int64((try? data.get(10) as UInt16) ?? 0)
        cell.frequency = Int32((try? data.get(12) as UInt16) ?? 0)
        let _: UInt32 = try data.get(14) // latitude
        let _: UInt32 = try data.get(18) // longitude
        
        return cell
    }
    
    private func parseUmtsAri(_ tlv: AriTlv, version: ALSTechnologyVersion) throws -> CCTCellProperties {
        var cell = CCTCellProperties()
        cell.technology = .UMTS
        
        if tlv.length != 28 {
            throw CCTParserError.unexpectedTlvLength
        }
        
        // Just a guess, we have not been able to validate this!
        let data = BinaryData(data: tlv.data, bigEndian: false)
        let _: UInt16 = try data.get(0) // index
        cell.mcc = Int32((try? data.get(2) as UInt16) ?? 0)
        cell.network = Int32((try? data.get(4) as UInt16) ?? 0)
        cell.band = Int32((try? data.get(6) as UInt16) ?? 0)
        cell.area = Int32((try? data.get(8) as UInt16) ?? 0)
        let _: UInt16 = try data.get(10) as UInt16 // unknown
        cell.cellId = Int64((try? data.get(12) as UInt32) ?? 0) // RNC-ID + Node-B cell id
        cell.frequency = Int32((try? data.get(16) as UInt16) ?? 0)
        let _: UInt16 = try data.get(18) // primary synchronization code (PSC)
        let _: UInt32 = try data.get(20) // latitude
        let _: UInt32 = try data.get(24) // longitude
        
        return cell
    }
    
    private func parseCdmaAri(_ tlv: AriTlv, version: ALSTechnologyVersion) throws -> CCTCellProperties {
        var cell = CCTCellProperties()
        cell.technology = .CDMA
        
        if (version == .cdma1x && tlv.length != 48) || (version == .cdmaEvdo && tlv.length != 52) {
            throw CCTParserError.unexpectedTlvLength
        }
        
        // Just a guess, we have not been able to validate this!
        let data = BinaryData(data: tlv.data, bigEndian: false)
        let _: UInt16 = try data.get(0) // index
        cell.mcc = Int32((try? data.get(2) as UInt16) ?? 0)
        
        if version == .cdma1x {
            let _ = Int32((try? data.get(4) as UInt16) ?? 0) // mnc
            cell.frequency = Int32((try? data.get(6) as UInt16) ?? 0)
            cell.band = Int32((try? data.get(8) as UInt16) ?? 0)
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
            cell.frequency = Int32((try? data.get(4) as UInt16) ?? 0)
            cell.band = Int32((try? data.get(6) as UInt16) ?? 0)
            let _ = try data.getUTF8(8, length: 16) // sectorID
            let _: UInt32 = try data.get(24) // latitude
            let _: UInt32 = try data.get(28) // longitude
            cell.area = Int32((try? data.get(32) as UInt16) ?? 0)
        }
        
        return cell
    }
    
    private func parseLteAri(_ tlv: AriTlv, version: ALSTechnologyVersion) throws -> CCTCellProperties {
        var cell = CCTCellProperties()
        cell.technology = .LTE
        
        if (version == .lte && tlv.length != 32) || (version == .lteV1T && tlv.length != 36) ||
            (version == .lteR15 && tlv.length != 36) || (version == .lteR15V2 && tlv.length != 52) {
            throw CCTParserError.unexpectedTlvLength
        }
        
        var offset = 0
        let data = BinaryData(data: tlv.data, bigEndian: false)
        
        let _: UInt16 = try data.get(0) // index
        cell.mcc = Int32((try? data.get(2) as UInt16) ?? 0)
        cell.network = Int32((try? data.get(4) as UInt16) ?? 0)
        cell.band = Int32((try? data.get(6) as UInt16) ?? 0)
        // According to the specification, the TAC uses just 16 bit. Therefore, this conversion causes no overflow.
        cell.area = Int32((try? data.get(8) as UInt32) ?? 0)
        // See: https://dev.seemoo.tu-darmstadt.de/apple/cell-guard/-/issues/98
        cell.cellId = Int64((try? data.get(12) as UInt32) ?? 0)
        
        offset = 16
        if version == .lte {
            cell.frequency = Int32((try? data.get(offset) as UInt16) ?? 0)
            offset += 2
            cell.physicalCellId = Int32((try? data.get(offset) as UInt16) ?? 0)
            offset += 2
        } else if version == .lteV1T || version == .lteR15 || version == .lteR15V2 {
            // With a max value of 262143, the conversion causes no overflow.
            cell.frequency = Int32((try? data.get(offset) as UInt32) ?? 0)
            offset += 4
            cell.physicalCellId = Int32((try? data.get(offset) as UInt32) ?? 0)
            offset += 4
        }
        
        let _: UInt32 = try data.get(offset) // latitude
        offset += 4
        let _: UInt32 = try data.get(offset) // longitude
        offset += 4
        cell.bandwidth = Int32((try? data.get(offset) as UInt8) ?? 0)
        offset += 1
        
        if version != .lte {
            cell.deploymentType = Int32((try? data.get(offset) as UInt8) ?? 0)
            offset += 1
        }
        
        return cell
    }
    
    private func parseNrAri(_ tlv: AriTlv, version: ALSTechnologyVersion) throws -> CCTCellProperties {
        var cell = CCTCellProperties()
        cell.technology = .NR
        
        if (version == .nr && tlv.length != 104) || (version == .nrV2 && tlv.length != 120) {
            throw CCTParserError.unexpectedTlvLength
        }

        let data = BinaryData(data: tlv.data, bigEndian: false)
        let _: UInt32 = try data.get(0) // index
        cell.mcc = Int32((try? data.get(4) as UInt16) ?? 0)
        cell.network = Int32((try? data.get(6) as UInt16) ?? 0)
        cell.band = Int32((try? data.get(8) as UInt32) ?? 0)
        // According to the specification, the TAC uses just 36 bit. Therefore, this conversion causes no overflow.
        cell.area = Int32((try? data.get(12) as UInt32) ?? 0)
        // According to the specification, the cell ID uses just 36 bit. Therefore, this conversion causes no overflow.
        cell.cellId = Int64((try? data.get(16) as UInt64) ?? 0)
        // With a max value of 3279165, this conversion causes no overflow.
        cell.frequency = Int32((try? data.get(24) as UInt32) ?? 0)
        cell.physicalCellId = Int32((try? data.get(28) as UInt32) ?? 0)
        let _: UInt32 = try data.get(32) // latitude
        let _: UInt32 = try data.get(36) // longitude
        cell.bandwidth = Int32((try? data.get(40) as UInt16) ?? 0)
        let _: UInt16 = try data.get(42) // scs
        let _: UInt32 = try data.get(44) // gscn
        let _: UInt16 = try data.get(48) // bwpSupport
        let _: UInt32 = try data.get(50) // throughput
        let _: UInt16 = try data.get(54) // pMax
        
        return cell
    }
}
