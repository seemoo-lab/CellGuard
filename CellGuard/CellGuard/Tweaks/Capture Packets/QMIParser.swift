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
    case InvalidContentLength(UInt16, UInt16)
    case EmptyTLV
}

// Sources:
// - https://dev.seemoo.tu-darmstadt.de/apple/iphone-qmi-wireshark/-/blob/main/dissector/qmi_dissector_template.lua
// - https://nextcloud.seemoo.tu-darmstadt.de/s/pqsrRgggBPt3psZ

struct ParsedQMIPacket {
    let qmuxHeader: QMIQMuxHeader
    let transactionHeader: QMITransactionHeader
    let messageHeader: QMIMessageHeader
    let tlvs: [QMITLV]
    
    init(nsData: Data) throws {
        // QMI packets have 3 headers followed by an arbitrary number of TLVs holding the packet's content.
        // As QMI respects byte boundaries, we can use the convenient library BinarySwift for parsing QMI packets.
        // Multi-byte fields in QMI use the low endian byte order.
        
        // We use the offset variable to keep track of the bytes already processed.
        var offset = 0
        
        // QMux Header (6 Bytes)
        qmuxHeader = try QMIQMuxHeader(nsData: nsData.subdata(in: offset..<offset+6))
        
        // The header's packet size excludes the magic byte at the beginning.
        if qmuxHeader.length != nsData.count - 1 {
            throw QMIParseError.InvalidPacketLength(qmuxHeader.length, UInt16(nsData.count - 1))
        }
        
        offset += 6
        
        // Transaction Header (2 or 3 Bytes)
        // This header has a size of 2 bytes for packets with the service id 0x00 (CTL) and 3 bytes for all other packets.
        let transactionHeaderLength = qmuxHeader.serviceId == 0x00 ? 2 : 3
        transactionHeader = try QMITransactionHeader(nsData: nsData.subdata(in: offset..<offset+transactionHeaderLength))
        
        offset += transactionHeaderLength
        
        // Message Header (4 Bytes)
        messageHeader = try QMIMessageHeader(nsData: nsData.subdata(in: offset..<offset+4))
        
        offset += 4
        
        // Check that content length of the packet matches with the header
        if messageHeader.messageLength != nsData.count - offset {
            throw QMIParseError.InvalidPacketLength(messageHeader.messageLength, UInt16(nsData.count - offset))
        }
        
        // TLVs (Variable Size)
        var tmpTLVs: [QMITLV] = []
        while offset < nsData.count {
            let tlv = try QMITLV(nsData: nsData.subdata(in: offset..<nsData.count))
            tmpTLVs.append(tlv)
            
            // The TLV header has a size of 3 bytes
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
        let data = BinaryData(data: nsData, bigEndian: false)
        
        // The first byte must be the QMI magic byte 0x01
        let tf: UInt8 = try data.get(0)
        if tf != 0x01 {
            throw QMIParseError.InvalidQMuxStart(tf)
        }
        
        // The next two store the packet's length, excluding the first magic byte
        length = try data.get(1)
        
        // The flag holds the direction of the packet.
        // 0x00 = iOS -> Baseband
        // 0x80 = Baseband -> iOS
        flag = try data.get(3)
        if flag != 0x00 && flag != 0x80 {
            throw QMIParseError.InvalidQMuxFlag(flag)
        }
        
        // The service id is central to identifying a packet's function.
        serviceId = try data.get(4)
        // There can be multiple clients for a given service.
        clientId = try data.get(5)
    }
}

struct QMITransactionHeader {
    let compound: Bool
    let response: Bool
    let indication: Bool
    let transactionId: UInt16
    
    init(nsData: Data) throws {
        let data = BinaryData(data: nsData, bigEndian: false)
        
        // The transaction header holds a one-byte bitfield and
        // a two- or three-byte transaction id for identifying related packets.
        
        let transactionBitfield: UInt8 = try data.get(0)
        
        // Based on the header's length the bitfield contains different information.
        if nsData.count == 2 {
            // QMI packets of the 0x00 (CTL) service have only a two-byte transaction header
            compound = false
            response = transactionBitfield & 0b00000001 != 0
            indication = transactionBitfield & 0b00000010 != 0
            
            let tmpTransactionId: UInt8 = try data.get(1)
            transactionId = UInt16(tmpTransactionId)
        } else {
            // QMI packets of other services have only a three-byte transaction header
            compound = transactionBitfield & 0b00000001 != 0
            response = transactionBitfield & 0b00000010 != 0
            indication = transactionBitfield & 0b00000100 != 0
            
            transactionId = try data.get(1)
        }
    }
}

struct QMIMessageHeader {
    let messageId: UInt16
    let messageLength: UInt16
    
    init(nsData: Data) throws {
        let data = BinaryData(data: nsData, bigEndian: false)
        
        // The message holds information about the packet's content length and its function.
        
        // The combination of the service id and the two-byte message id assign each packet its function.
        messageId = try data.get(0)
        // The two-byte message length only counts the TLV bytes
        messageLength = try data.get(2)
    }
}

struct QMITLV {
    let type: UInt8
    let length: UInt16
    let data: Data
    
    init(nsData: Data) throws {
        let data = BinaryData(data: nsData, bigEndian: false)
        
        // Type-Length-Value (TLV) elements have a three-byte header that defines their variable data size.
        
        // The one-byte type
        type = try data.get(0)
        // The two-byte length of the following data
        length = try data.get(1)
        // The actual content of the TLV
        self.data = nsData.subdata(in: 3..<1+2+Int(length))
        
        // No TLV has a length of zero, so we throw an error to prevent an infinite parsing loop.
        if length == 0 {
            throw QMIParseError.EmptyTLV
        }
    }
}
