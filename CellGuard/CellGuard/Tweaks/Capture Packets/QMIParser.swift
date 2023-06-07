//
//  QMIParser.swift
//  CellGuard
//
//  Created by Lukas Arnold on 06.06.23.
//

import Foundation
import BinarySwift

enum QMIParseError: Error {
    case InvalidQMuxStart(UInt8)
    case InvalidQMuxFlag(UInt8)
    case InvalidPacketLength(UInt16, UInt16)
    case EmptyTLV
}

// TODO: Service & Message Names

// Sources:
// - https://dev.seemoo.tu-darmstadt.de/apple/iphone-qmi-wireshark/-/blob/main/dissector/qmi_dissector_template.lua
// - https://nextcloud.seemoo.tu-darmstadt.de/s/pqsrRgggBPt3psZ

struct ParsedQMIPacket {
    let qmuxHeader: QMIQMuxHeader
    let transactionHeader: QMITransactionHeader
    let messageHeader: QMIMessageHeader
    let tlvs: [QMITLV]
    
    init(nsData: Data) throws {
        var offset = 0
        // QMux Header
        qmuxHeader = try QMIQMuxHeader(nsData: nsData.subdata(in: offset..<offset+6))
        
        if qmuxHeader.length != nsData.count - 1 {
            throw QMIParseError.InvalidPacketLength(qmuxHeader.length, UInt16(nsData.count - 1))
        }
        
        offset += 6
        
        // Transaction Header
        let transactionHeaderLength = qmuxHeader.serviceId == 0x00 ? 2 : 3
        transactionHeader = try QMITransactionHeader(nsData: nsData.subdata(in: offset..<offset+transactionHeaderLength))
        
        offset += transactionHeaderLength
        
        // Message Header
        messageHeader = try QMIMessageHeader(nsData: nsData.subdata(in: offset..<offset+4))
        
        offset += 4
        
        // TLVs
        var tmpTLVs: [QMITLV] = []
        let messageEnd = UInt16(offset) + messageHeader.messageLength
        while offset < messageEnd {
            let tlv = try QMITLV(nsData: nsData.subdata(in: offset..<nsData.count))
            tmpTLVs.append(tlv)
            
            offset += 1 + 2 + Int(tlv.length)
        }
        tlvs = tmpTLVs
    }
    
}

struct QMIQMuxHeader {
    let length: UInt16
    let flag: UInt8
    let serviceId: UInt8
    let clientId: UInt8
    
    init(nsData: Data) throws {
        let data = BinaryData(data: nsData)
        
        let tf: UInt8 = try data.get(0)
        if tf != 0x01 {
            throw QMIParseError.InvalidQMuxStart(tf)
        }
        
        length = try data.get(1, bigEndian: false)
        
        flag = try data.get(3)
        if flag != 0x00 && flag != 0x80 {
            throw QMIParseError.InvalidQMuxFlag(flag)
        }
        
        serviceId = try data.get(4)
        clientId = try data.get(5)
    }
}

struct QMITransactionHeader {
    let compound: Bool
    let response: Bool
    let indication: Bool
    let transactionId: UInt16
    
    init(nsData: Data) throws {
        let data = BinaryData(data: nsData)
        let transactionBitfield: UInt8 = try data.get(0)
        
        if nsData.count == 2 {
            compound = false
            response = transactionBitfield & 0b00000001 != 0
            indication = transactionBitfield & 0b00000010 != 0
            
            let tmpTransactionId: UInt8 = try data.get(1, bigEndian: false)
            transactionId = UInt16(tmpTransactionId)
        } else {
            compound = transactionBitfield & 0b00000001 != 0
            response = transactionBitfield & 0b00000010 != 0
            indication = transactionBitfield & 0b00000100 != 0
            
            transactionId = try data.get(1, bigEndian: false)
        }
    }
}

struct QMIMessageHeader {
    let messageId: UInt16
    let messageLength: UInt16
    
    init(nsData: Data) throws {
        let data = BinaryData(data: nsData)
        
        messageId = try data.get(0, bigEndian: false)
        messageLength = try data.get(2, bigEndian: false)
    }
}

struct QMITLV {
    let type: UInt8
    let length: UInt16
    let data: Data
    
    init(nsData: Data) throws {
        let data = BinaryData(data: nsData)
        
        type = try data.get(0)
        length = try data.get(1, bigEndian: false)
        self.data = nsData.subdata(in: 3..<1+2+Int(length))
        
        if length == 0 {
            throw QMIParseError.EmptyTLV
        }
    }
}
