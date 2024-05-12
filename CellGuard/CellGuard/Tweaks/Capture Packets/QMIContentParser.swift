//
//  QMIPacketParser.swift
//  CellGuard
//
//  Created by Lukas Arnold on 26.07.23.
//

import Foundation
import BinarySwift

enum ParsedContentQMIPacketError: Error  {
    case wrongServiceId
    case wrongMessageId
    case noIndication
}

struct ParsedQMISignalInfoIndication {
    
    let gsm: Int8? // RSSI: dBm
    let lte: LTESignalStrengthQMI?
    let nr: NRSignalStrengthQMI?
    
    init(qmiPacket: ParsedQMIPacket) throws {
        // The packet is part of the NAS service
        if qmiPacket.qmuxHeader.serviceId != 0x03 {
            throw ParsedContentQMIPacketError.wrongServiceId
        }
        
        // The packet is an indication
        if !qmiPacket.transactionHeader.indication {
            throw ParsedContentQMIPacketError.noIndication
        }
        
        // The packet has the message id of 0x0051
        if qmiPacket.messageHeader.messageId != 0x0051 {
            throw ParsedContentQMIPacketError.wrongMessageId
        }
        
        if let gsmTLV = qmiPacket.tlvs.first(where: {$0.type == 0x12}), let gsmStrengthUInt = gsmTLV.data.first {
            // Don't convert the value of the UInt8 to an Int8, use instead its bit pattern
            gsm = Int8(bitPattern: gsmStrengthUInt)
        } else {
            gsm = nil
        }
        
        if let lteTLV = qmiPacket.tlvs.first(where: { $0.type ==  0x14}) {
            lte = try LTESignalStrengthQMI(data: lteTLV.data)
        } else {
            lte = nil
        }
        
        if let nrTLV = qmiPacket.tlvs.first(where: { $0.type == 0x17 }), let nrExtTLV = qmiPacket.tlvs.first(where: { $0.type == 0x18 }) {
            nr = try NRSignalStrengthQMI(data: nrTLV.data, extendedData: nrExtTLV.data)
        } else {
            nr = nil
        }
    }
    
}

struct LTESignalStrengthQMI {
    
    // See:
    // - https://gitlab.freedesktop.org/mobile-broadband/libqmi/-/blob/main/data/qmi-service-nas.json#L4249
    // - https://gitlab.freedesktop.org/mobile-broadband/libqmi/-/blob/main/data/qmi-service-nas.json#L4249
    
    let rssi: Int8 // dBm
    let rsrq: Int8 // dB
    let rsrp: Int16 // dBm
    let snr: Int16 // dB
    
    init(data: Data) throws {
        let binaryData = BinaryData(data: data, bigEndian: false)
        rssi = try binaryData.get(0)
        rsrq = try binaryData.get(1)
        rsrp = try binaryData.get(2)
        snr = try binaryData.get(4)
    }
}

struct NRSignalStrengthQMI {
    
    // See:
    // - https://gitlab.freedesktop.org/mobile-broadband/libqmi/-/blob/main/data/qmi-service-nas.json#L3883
    
    static let missing: Int16 = Int16(bitPattern: UInt16(0x8000))
    
    let rsrp: Int16? // dBm
    let snr: Int16? // dB
    let rsrq: Int16? // dB
    
    init(data: Data, extendedData: Data) throws {
        let binaryData = BinaryData(data: data, bigEndian: false)
        rsrp = Self.nilIfMissing(try binaryData.get(0))
        snr = Self.nilIfMissing(try binaryData.get(2))
        
        let extendedBinaryData = BinaryData(data: extendedData, bigEndian: false)
        rsrq = Self.nilIfMissing(try extendedBinaryData.get(0))
    }
    
    private static func nilIfMissing(_ number: Int16) -> Int16? {
        return number != missing ? number : nil
    }
    
}
