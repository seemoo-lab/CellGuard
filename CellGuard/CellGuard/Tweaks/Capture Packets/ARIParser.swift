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

// TODO: Names
// TODO: Comment

enum ARIParseError: Error {
    case HeaderMissing
    case InvalidMagicBytes
    case InvalidPacketLength(UInt16, UInt16)
}

struct ParsedARIPacket {
    
    let header: ARIHeader
    let tlvs: [ARITLV]
    
    init(data: Data) throws {
        if (data.count < 12) {
            throw ARIParseError.HeaderMissing
        }
        
        header = try ARIHeader(data: data.subdata(in: 0..<12))
        
        if header.length + 12 != data.count {
            throw ARIParseError.InvalidPacketLength(header.length + 12, UInt16(data.count))
        }
        
        var offset = 12
        var tmpTLVs: [ARITLV] = []
        while offset < data.count {
            let tlv = try ARITLV(data: data.subdata(in: offset..<data.count))
            tmpTLVs.append(tlv)
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
        let magicBytes = data.subdata(in: 0..<4)
        if magicBytes != Data([0xDE, 0xC0, 0x7E, 0xAB]) {
            throw ARIParseError.InvalidMagicBytes
        }
        
        // As a rule of thumb: Everything is low-endian encoded
        self.group = ((data[5] & 0b00000001) << 5) | ((data[4] & 0b11111000) >> 3)
        self.sequenceNumber = (UInt16(data[8] & 0b00000111) << 8) | (UInt16(data[6] & 0b00000001) << 7) | (UInt16(data[5] & 0b11111110) >> 1)
        self.length = UInt16(data[7] << 7) | (UInt16(data[6] & 0b11111110) >> 1)
        self.type = (UInt16(data[9]) << 2) | (UInt16(data[8] & 0b11000000) >> 6)
        self.transaction = (UInt16(data[11]) << 7) | (UInt16(data[10]) >> 1)
        self.acknowledgement = ((data[8] & 0b00001000) >> 3) != 0
    }
    
}

struct ARITLV {
    
    let type: UInt16
    let version: UInt8
    let length: UInt16
    let data: Data
    
    init (data: Data) throws {
        // TODO: Length
        self.type = (UInt16(data[1] & 0b00011111) << 7) | (UInt16(data[0] & 0b11111110) >> 1)
        self.version = data[1] >> 5
        self.length = (UInt16(data[3]) << 6) | (UInt16(data[2] & 0b11111100) >> 2)
        self.data = data.subdata(in: 4..<4+Int(length))
    }
    
}
