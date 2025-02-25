//
//  ARIParser.swift
//  CellGuard
//
//  Created by Lukas Arnold on 06.06.23.
//

import BinarySwift
import Foundation
import NIOCore

// Sources:
// - https://github.com/seemoo-lab/aristoteles/blob/master/ari.lua
// - https://tuprints.ulb.tu-darmstadt.de/19397/1/Thesis.pdf

enum ARIParseError: Error {
    case HeaderMissing
    case InvalidMagicBytes
    case InvalidPacketLength(UInt16, UInt16)
}

enum ARIGenerationError: Error {
    case TLVsTooLong(max: Int, length: Int)
    case HeaderFieldTooLong(field: String, max: Int, length: Int)
    case TLVFieldTooLong(field: String, max: Int, length: Int)
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
    
    init(group: UInt8, type: UInt16, transaction: UInt16, sequenceNumber: UInt16, acknowledgement: Bool, tlvs: [ARITLV]) throws {
        let tlvByteCount = tlvs.map { $0.byteCount }.reduce(0, +)
        if tlvByteCount >= 1 << 15 {
            throw ARIGenerationError.TLVsTooLong(max: Int(UInt16.max), length: tlvByteCount)
        }
        
        self.header = try ARIHeader(group: group, sequenceNumber: sequenceNumber, length: UInt16(tlvByteCount), type: type, transaction: transaction, acknowledgement: acknowledgement)
        self.tlvs = tlvs
    }
    
    func write() throws -> Data {
        var buffer = ByteBuffer()
        var scratch = ByteBuffer()
        
        // Write the header
        self.header.write(buffer: &buffer, scratch: &scratch)
        
        // Write all TLVs
        for tlv in tlvs {
            tlv.write(buffer: &buffer, scratch: &scratch)
        }
        
        // Read bytes from buffer and convert it to Data
        guard let bytes = buffer.readBytes(length: buffer.readableBytes) else {
            throw QMIGenerationError.CantReadBuffer
        }
        return Data(bytes)
    }
    
    func findTlvValue(type: UInt8) -> ARITLV? {
        return self.tlvs.filter({ $0.type == type }).first
    }
}

struct ARIHeader {
    
    private static let magicBytes: [UInt8] = [0xDE, 0xC0, 0x7E, 0xAB]
    
    let byteCount = 12
    
    let group: UInt8
    let sequenceNumber: UInt16
    let length: UInt16
    let type: UInt16 // = messageId
    let transaction: UInt16
    let acknowledgement: Bool
    
    fileprivate init(data: Data) throws {
        // Each ARI packet starts with 4 magic bytes
        let magicBytes = data.subdata(in: 0..<4)
        if magicBytes != Data(magicBytes) {
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
    
    fileprivate init(group: UInt8, sequenceNumber: UInt16, length: UInt16, type: UInt16, transaction: UInt16, acknowledgement: Bool) throws {
        if group >= (1 << 6) {
            throw ARIGenerationError.HeaderFieldTooLong(field: "group", max: Int(1 << 6), length: Int(group))
        }
        if sequenceNumber >= (1 << 11) {
            throw ARIGenerationError.HeaderFieldTooLong(field: "sequenceNumber", max: Int(1 << 11), length: Int(group))
        }
        if length >= (1 << 15) {
            throw ARIGenerationError.HeaderFieldTooLong(field: "length", max: Int(1 << 15), length: Int(group))
        }
        if type >= (1 << 10) {
            throw ARIGenerationError.HeaderFieldTooLong(field: "type", max: Int(1 << 10), length: Int(group))
        }
        if transaction >= (1 << 15) {
            throw ARIGenerationError.HeaderFieldTooLong(field: "transaction", max: Int(1 << 15), length: Int(group))
        }
        
        self.group = group
        self.sequenceNumber = sequenceNumber
        self.length = length
        self.type = type
        self.transaction = transaction
        self.acknowledgement = acknowledgement
    }
    
    fileprivate func write(buffer: inout ByteBuffer, scratch: inout ByteBuffer) {
        // magicBytes: (3) (2) (1) (0)
        buffer.writeBytes(Self.magicBytes)
        
        // group: (4) 11111000
        buffer.writeInteger(UInt8(truncatingIfNeeded: 0b11111000 & group << 3))
        
        // sequenceNumber: (5) 11111110, group: (5) 00000001
        buffer.writeInteger(UInt8(truncatingIfNeeded: 0b11111110 & sequenceNumber << 1) | UInt8(truncatingIfNeeded: 0b00000001 & group >> 5))
        
        // length: (6) 11111110, sequenceNumber: (6) 00000001
        buffer.writeInteger(UInt8(truncatingIfNeeded: 0b11111110 & length << 1) | UInt8(truncatingIfNeeded: 0b00000001 & sequenceNumber >> 7))
        
        // length: (7) 11111111
        buffer.writeInteger(UInt8(truncatingIfNeeded: length >> 7))
        
        // type: (8) 11000000, acknowledgement: (8) 00001000, sequenceNumber: (8) 00000111
        let ackBit = acknowledgement ? UInt8(1) : UInt8(0)
        buffer.writeInteger(UInt8(truncatingIfNeeded: 0b11000000 & type << 6) | ackBit << 3 | UInt8(truncatingIfNeeded: 0b00000111 & sequenceNumber >> 8))
        
        // type: (9) 11111111
        buffer.writeInteger(UInt8(truncatingIfNeeded: type >> 2))
        
        // transaction: (10) 11111110
        buffer.writeInteger(UInt8(truncatingIfNeeded: transaction << 1))
        
        // transaction: (11) 11111111
        buffer.writeInteger(UInt8(truncatingIfNeeded: transaction >> 7))
    }
    
}

struct ARITLV {
    
    var byteCount: Int {
        return 4 + Int(length)
    }
    
    let type: UInt16
    let version: UInt8
    let length: UInt16
    let data: Data
    
    fileprivate init(data: Data) throws {
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
    
    init(type: UInt16, version: UInt8, data: Data) throws {
        if type >= (1 << 12) {
            throw ARIGenerationError.TLVFieldTooLong(field: "type", max: (1 << 12) - 1, length: data.count)
        }
        if version >= (1 << 3) {
            throw ARIGenerationError.TLVFieldTooLong(field: "version", max: (1 << 3) - 1, length: data.count)
        }
        if data.count > (1 << 14) {
            throw ARIGenerationError.TLVFieldTooLong(field: "data", max: (1 << 14) - 1, length: data.count)
        }
        
        self.type = type
        self.version = version
        self.length = UInt16(data.count)
        self.data = data
    }
    
    func uint() -> UInt32? {
        if data.count != 4 {
            print("ARI TLV data has the wrong number of bytes \(data.count) for UInt32 conversion")
            return nil
        }
        
        do {
            return try BinaryData(data: data, bigEndian: false).get(0)
        } catch {
            print("ARI TLV data to UInt32 conversion failed: \(error)")
            return nil
        }
    }
    
    func hasEmptyData() -> Bool {
        return length == 0 || data.allSatisfy { $0 == 0 }
    }
    
    fileprivate func write(buffer: inout ByteBuffer, scratch: inout ByteBuffer) {
        // type: (0) 11111110
        buffer.writeInteger(UInt8(truncatingIfNeeded: 0b01111111 & type << 1))
        
        // version: (1) 11100000, type: (1) 00011111
        buffer.writeInteger(UInt8(truncatingIfNeeded: version << 5) | UInt8(truncatingIfNeeded: 0b00011111 & type >> 7))
        
        // length: (2) 11111100
        buffer.writeInteger(UInt8(truncatingIfNeeded: 0b11111100 & length << 2))
        
        // length: (3) 11111111
        buffer.writeInteger(UInt8(truncatingIfNeeded: length >> 6))
        
        // data
        buffer.writeBytes(data)
    }
    
}
