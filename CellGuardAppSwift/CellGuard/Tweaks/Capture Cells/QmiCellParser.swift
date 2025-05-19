//
//  QmiCellParser.swift
//  CellGuard
//
//  Created by mp on 01.04.25.
//

import Foundation
import BinarySwift

extension CCTParser {

    func parseQmiCell(_ data: Data, timestamp: Date, simSlot: UInt8) throws -> [CCTCellProperties] {
        // Location for symbols:
        // - Own sample collection using the tweak
        // - IPSW: /System/Library/Frameworks/CoreTelephony.framework/CoreTelephony (dyld_cache)
        // - https://github.com/nahum365/CellularInfo/blob/master/CellInfoView.m#L32

        let parsedPacket = try ParsedQMIPacket(nsData: data)

        if parsedPacket.qmuxHeader.serviceId != PacketConstants.qmiCellInfoService {
            throw CCTParserError.invalidQmiService
        }
        if parsedPacket.messageHeader.messageId != PacketConstants.qmiCellInfoMessage {
            throw CCTParserError.invalidQmiMessage
        }
        if !parsedPacket.transactionHeader.indication && !parsedPacket.transactionHeader.response {
            throw CCTParserError.invalidQmiDirection
        }

        var cells: [CCTCellProperties] = []
        for technology in PacketConstants.qmiCellInfoTechnologies {
            guard let tlvType = PacketConstants.qmiCellInfoTLVTypes[technology],
                  let tlv = parsedPacket.findTlvValue(type: tlvType) else {
                continue
            }

            var cell: CCTCellProperties?
            switch technology {
            case .cdma1x, .cdmaEvdo:
                // https://en.wikipedia.org/wiki/CDMA2000
                // CDMA2000 1x Evolution-Data Optimized
                cell = try? parseCdmaQmi(tlv, version: technology)
            case .umts, .tdscdma:
                // Special version of UMTS WCDMA in China
                // https://www.electronics-notes.com/articles/connectivity/3g-umts/td-scdma.php
                cell = try? parseUmtsQmi(tlv, version: technology)
            case .gsm:
                cell = try? parseGsmQmi(tlv)
            case .lteV1, .lteV2, .lteV3, .lteV4:
                cell = try? parseLteQmi(tlv, version: technology)
            case .nr, .nrV2, .nrV3:
                cell = try? parseNrQmi(tlv, version: technology)
            default:
                throw CCTParserError.unknownRat(technology.rawValue)
            }

            if var cell = cell,
               !cell.isMissingKeyProperties() {
                cell.preciseTechnology = technology.rawValue
                cell.timestamp = timestamp
                cell.simSlotID = simSlot

                // We keep only the most recent cell technology info version, e.g. we use the `lteV4` cell infos, if available, instead of the
                // `.lteV1`, `.lteV2`, or `lteV3` cell infos. The order is defined by the PacketConstants.qmiCellInfoTechnologies.
                if let index = cells.firstIndex(where: { $0.technology == cell.technology }) {
                    cells[index] = cell
                } else {
                    cells.append(cell)
                }
            }
        }

        if cells.isEmpty {
            // We store empty cells to indicate that the baseband is disconnected.
            var cell = CCTCellProperties()
            cell.technology = ALSTechnology.OFF
            cell.timestamp = timestamp
            cell.simSlotID = simSlot
            cells.append(cell)
        }

        return cells
    }

    private func parseGsmQmi(_ tlv: QmiTlv) throws -> CCTCellProperties {
        var cell = CCTCellProperties()
        cell.technology = .GSM

        if tlv.length != 22 {
            throw CCTParserError.unexpectedTlvLength
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

    private func parseUmtsQmi(_ tlv: QmiTlv, version: ALSTechnologyVersion) throws -> CCTCellProperties {
        var cell = CCTCellProperties()
        cell.technology = .UMTS

        // UMTS has been phased out in many countries
        // https://de.wikipedia.org/wiki/Universal_Mobile_Telecommunications_System

        // Therefore this is just a guess and not tested but it should be the similar to GSM
        // https://en.wikipedia.org/wiki/Mobility_management#Location_area

        // With some data collected in Austria, we could confirm this
        // There's also the field "SCN" which could be an abbreviation for sub-channel number

        if tlv.length != 26 {
            throw CCTParserError.unexpectedTlvLength
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

    private func parseCdmaQmi(_ tlv: QmiTlv, version: ALSTechnologyVersion) throws -> CCTCellProperties {
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
            throw CCTParserError.unexpectedTlvLength
        }

        // See: https://dev.seemoo.tu-darmstadt.de/apple/iphone-qmi-wireshark/-/blob/main/dissector/qmi_dissector_template.lua
        let data = BinaryData(data: tlv.data, bigEndian: false)
        let _: UInt8 = try data.get(0) // array_length
        let _: UInt16 = try data.get(1) // index
        cell.mcc = Int32((try? data.get(3) as UInt16) ?? 0)

        if version == .cdma1x {
            _ = Int32((try? data.get(5) as UInt16) ?? 0) // mnc
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
            cell.band = Int32((try? data.get(6) as UInt16) ?? 0) + 1 // The offset by one provides alignment with the iOS libraries
            _ = try data.getUTF8(8, length: 16) // sectorID
            let _: UInt32 = try data.get(24) // latitude
            let _: UInt32 = try data.get(28) // longitude
            cell.area = Int32((try? data.get(32) as UInt16) ?? 0)
        }

        return cell
    }

    private func parseLteQmi(_ tlv: QmiTlv, version: ALSTechnologyVersion) throws -> CCTCellProperties {
        var cell = CCTCellProperties()
        cell.technology = .LTE

        // We currently do not have support for array_length != 1 as then a multiple of the payload length would be transmitted.
        // However, we have not seen such CellInformation messages so far.
        if (version == .lteV1 && tlv.length != 27) || (version == .lteV2 && tlv.length != 29) ||
            (version == .lteV3 && tlv.length != 32) || (version == .lteV4 && tlv.length != 49) {
            throw CCTParserError.unexpectedTlvLength
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
            // According to the specification, the TAC uses just 16 bit. Therefore, this conversion causes no overflow.
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

    private func parseNrQmi(_ tlv: QmiTlv, version: ALSTechnologyVersion) throws -> CCTCellProperties {
        var cell = CCTCellProperties()
        cell.technology = .NR

        if (version == .nr && tlv.length == 38) || (version == .nrV2 && tlv.length != 42) || (version == .nrV3 && tlv.length != 57) {
            throw CCTParserError.unexpectedTlvLength
        }

        // See: https://dev.seemoo.tu-darmstadt.de/apple/iphone-qmi-wireshark/-/blob/main/dissector/qmi_dissector_template.lua
        var offset = 0
        let data = BinaryData(data: tlv.data, bigEndian: false)
        let _: UInt8 = try data.get(0) // array_length
        let _: UInt16 = try data.get(1) // index
        cell.mcc = Int32((try? data.get(3) as UInt16) ?? 0)
        cell.network = Int32((try? data.get(5) as UInt16) ?? 0)
        cell.band = Int32((try? data.get(7) as UInt16) ?? 0) + 1 // The offset by one provides alignment with the iOS libraries
        // According to the specification, the TAC uses just 24 bit. Therefore, this conversion causes no overflow.
        cell.area = Int32((try? data.get(9) as UInt32) ?? 0)

        offset = 13
        if version == .nr {
            cell.cellId = Int64((try? data.get(offset) as UInt32) ?? 0)
            offset += 4
        } else if version == .nrV2 || version == .nrV3 {
            // According to the specification, the cell ID uses just 36 bit. Therefore, this conversion causes no overflow.
            // With a max value of 3279165, this conversion causes no overflow.
            cell.cellId = Int64((try? data.get(offset) as UInt64) ?? 0)
            offset += 8
        }

        cell.frequency = Int32((try? data.get(offset) as UInt32) ?? 0)
        offset += 4
        cell.physicalCellId = Int32((try? data.get(offset) as UInt16) ?? 0)
        offset += 2
        let _: UInt32 = try data.get(offset) // latitude
        offset += 4
        let _: UInt32 = try data.get(offset) // longitude
        offset += 4
        cell.bandwidth = Int32((try? data.get(offset) as UInt16) ?? 0)
        offset += 2
        let _: UInt8 = try data.get(offset) // scs
        offset += 1
        let _: UInt32 = try data.get(offset) // gscn
        offset += 4

        if version == .nrV3 {
            let _: UInt8 = try data.get(offset) // bwpSupport
            offset += 1
            let _: UInt32 = try data.get(offset) // throughput
            offset += 4
            let _: UInt16 = try data.get(offset) // pMax
            offset += 2
            // Two unknown UInt32 values are left
        }

        return cell
    }
}
