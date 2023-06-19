//
//  ARIParser.swift
//  CellGuard
//
//  Created by Lukas Arnold on 06.06.23.
//

import BinarySwift
import Foundation

// Sources:
// - https://github.com/seemoo-lab/aristoteles/blob/master/ari.lua
// - https://tuprints.ulb.tu-darmstadt.de/19397/1/Thesis.pdf

enum ARIParseError: Error {
    case HeaderMissing
    case InvalidMagicBytes
    case InvalidPacketLength(UInt16, UInt16)
}

struct ParsedARIPacket: ParsedPacket {
    
    let header: ARIHeader
    let tlvs: [ARITLV]
    
    init(data: Data) throws {
        // The header has a size of 12 bytes
        if (data.count < 12) {
            throw ARIParseError.HeaderMissing
        }
        
        header = try ARIHeader(data: data.subdata(in: 0..<12))
        
        // The length field of the header does not include the header length itself
        if header.length + 12 != data.count {
            throw ARIParseError.InvalidPacketLength(header.length + 12, UInt16(data.count))
        }
        
        // We iterating through all TLVs making up the content of the ARI packet
        var offset = 12
        var tmpTLVs: [ARITLV] = []
        while offset < data.count {
            let tlv = try ARITLV(data: data.subdata(in: offset..<data.count))
            tmpTLVs.append(tlv)
            // The ARI header has a length of 4 bytes
            offset += 4 + Int(tlv.length)
        }
        self.tlvs = tmpTLVs
    }
    
}

struct ARIHeader {
    
    let group: UInt8
    let sequenceNumber: UInt16
    let length: UInt16
    let type: UInt16 // = messageId
    let transaction: UInt16
    let acknowledgement: Bool
    
    init(data: Data) throws {
        // Each ARI packet starts with 4 magic bytes
        let magicBytes = data.subdata(in: 0..<4)
        if magicBytes != Data([0xDE, 0xC0, 0x7E, 0xAB]) {
            throw ARIParseError.InvalidMagicBytes
        }
        
        // ARI does not respect byte boundaries like QMI does, instead fields are spread out over multiple bytes.
        // Therefore, we have apply bitmasks and shift bytes around to get the values.
        // As a rule of thumb, all fields use the low endian byte order.
        
        // Our comments before each field show the relevant bytes (starting from zero) and the bitmask applied to them
        
        // (5) 00000001 (4) 11111000
        self.group = (UInt8(data[5] & 0b00000001) << 5) | (UInt8(data[4] & 0b11111000) >> 3)
        // (8) 00000111 (7) 00000000 (6) 00000001 (5) 11111110
        self.sequenceNumber = (UInt16(data[8] & 0b00000111) << 8) | (UInt16(data[6] & 0b00000001) << 7) | (UInt16(data[5] & 0b11111110) >> 1)
        // (7) 11111111 (6) 11111110
        self.length = (UInt16(data[7]) << 7) | (UInt16(data[6] & 0b11111110) >> 1)
        // (9) 11111111 (8) 11000000
        self.type = (UInt16(data[9]) << 2) | (UInt16(data[8] & 0b11000000) >> 6)
        // (11) 11111111 (10) 11111110
        self.transaction = (UInt16(data[11]) << 7) | (UInt16(data[10] & 0b11111110) >> 1)
        // (8) 00001000
        self.acknowledgement = ((data[8] & 0b00001000) >> 3) != 0
    }
    
}

struct ARITLV {
    
    let type: UInt16
    let version: UInt8
    let length: UInt16
    let data: Data
    
    init (data: Data) throws {
        // Type-Length-Value (TLV) elements have a 4 byte header.
        
        // (1) 00011111 (0) 11111110
        self.type = (UInt16(data[1] & 0b00011111) << 7) | (UInt16(data[0] & 0b11111110) >> 1)
        // (1) 11100000
        self.version = data[1] >> 5
        // (3) 11111111 (2) 11111100
        self.length = (UInt16(data[3]) << 6) | (UInt16(data[2] & 0b11111100) >> 2)
        
        // The header's length field defines the number of value bytes following.
        self.data = data.subdata(in: 4..<4+Int(length))
    }
    
}
