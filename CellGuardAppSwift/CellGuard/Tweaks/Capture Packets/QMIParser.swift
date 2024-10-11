//
//  QMIParser.swift
//  CellGuard
//
//  Created by Lukas Arnold on 06.06.23.
//

import Foundation
import BinarySwift
import NIOCore

enum QMIParseError: Error {
    case InvalidQMuxStart(UInt8)
    case InvalidQMuxFlag(UInt8)
    case InvalidPacketLength(UInt16, UInt16)
    case InvalidContentLength(UInt16, UInt16)
}

enum QMIGenerationError: Error {
    case DataTooLong(max: Int, length: Int)
    case MessageTooLong(max: Int, length: Int)
    case TransactionIdTooLong(max: Int, length: Int)
    case PacketTooLong(max: Int, length: Int)
    case InvalidFlag(UInt8)
    case CantReadBuffer
}

// Sources:
// - https://dev.seemoo.tu-darmstadt.de/apple/iphone-qmi-wireshark/-/blob/main/dissector/qmi_dissector_template.lua
// - https://nextcloud.seemoo.tu-darmstadt.de/s/pqsrRgggBPt3psZ

struct ParsedQMIPacket: ParsedPacket {
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
        
        offset += qmuxHeader.byteCount
        
        // Transaction Header (2 or 3 Bytes)
        // This header has a size of 2 bytes for packets with the service id 0x00 (CTL) and 3 bytes for all other packets.
        let transactionHeaderLength = qmuxHeader.serviceId == 0x00 ? 2 : 3
        transactionHeader = try QMITransactionHeader(nsData: nsData.subdata(in: offset..<offset+transactionHeaderLength))
        
        offset += transactionHeader.byteCount
        
        // Message Header (4 Bytes)
        messageHeader = try QMIMessageHeader(nsData: nsData.subdata(in: offset..<offset+4))
        
        offset += messageHeader.byteCount
        
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
            offset += tlv.byteCount
        }
        tlvs = tmpTLVs
    }
    
    init (
        flag: UInt8, serviceId: UInt8, clientId: UInt8, messageId: UInt16,
        compound: Bool, indication: Bool, response: Bool, transactionId: UInt16,
        tlvs: [QMITLV]
    ) throws {
        self.tlvs = tlvs
        
        // Calculate and check the number of TLV bytes, i.e. the message length
        let tlvsByteCount = tlvs.map { $0.byteCount }.reduce(0, +)
        if tlvsByteCount > UInt16.max {
            throw QMIGenerationError.MessageTooLong(max: Int(UInt16.max), length: tlvsByteCount)
        }
        self.messageHeader = QMIMessageHeader(messageId: messageId, messageLength: UInt16(tlvsByteCount))
        
        // Generate the transaction header based on the service id (and check the txid bounds before)
        if serviceId == 0x00 {
            if transactionId > UInt8.max {
                throw QMIGenerationError.TransactionIdTooLong(max: Int(UInt8.max), length: Int(transactionId))
            }
            self.transactionHeader = QMITransactionHeader(response: response, indication: indication, transactionId: UInt8(transactionId))
        } else {
            self.transactionHeader = QMITransactionHeader(compound: compound, response: response, indication: indication, transactionId: transactionId)
        }
        
        // Calculate and check the packet length (that excludes the first magic byte)
        let packetLength = tlvsByteCount + messageHeader.byteCount + transactionHeader.byteCount + 5
        if packetLength > UInt16.max {
            throw QMIGenerationError.PacketTooLong(max: Int(UInt16.max), length: packetLength)
        }
        self.qmuxHeader = try QMIQMuxHeader(length: UInt16(packetLength), flag: flag, serviceId: serviceId, clientId: clientId)
    }
    
    func write() throws -> Data {
        var buffer = ByteBuffer()
        
        // Write the packet headers
        self.qmuxHeader.write(buffer: &buffer)
        self.transactionHeader.write(buffer: &buffer)
        self.messageHeader.write(buffer: &buffer)
        
        // Write all TLVs
        for tlv in tlvs {
            tlv.write(buffer: &buffer)
        }
        
        // Read bytes from buffer and convert it to Data
        guard let bytes = buffer.readBytes(length: buffer.readableBytes) else {
            throw QMIGenerationError.CantReadBuffer
        }
        return Data(bytes)
    }
    
}

struct QMIQMuxHeader {
    private static let allowedFlags: [UInt8] = [0x00, 0x01, 0x80, 0x81]
    
    let byteCount = 6
    
    let length: UInt16
    let flag: UInt8
    let serviceId: UInt8
    let clientId: UInt8
    
    fileprivate init(nsData: Data) throws {
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
        if !Self.allowedFlags.contains(flag) {
            throw QMIParseError.InvalidQMuxFlag(flag)
        }
        
        // The service id is central to identifying a packet's function.
        serviceId = try data.get(4)
        // There can be multiple clients for a given service.
        clientId = try data.get(5)
    }
    
    fileprivate init (length: UInt16, flag: UInt8, serviceId: UInt8, clientId: UInt8) throws {
        if !Self.allowedFlags.contains(flag) {
            throw QMIGenerationError.InvalidFlag(flag)
        }
        
        self.length = length
        self.flag = flag
        self.serviceId = serviceId
        self.clientId = clientId
    }
    
    fileprivate func write(buffer: inout ByteBuffer) {
        // Magic Byte
        buffer.writeInteger(UInt8(0x01), endianness: .little)
        buffer.writeInteger(length, endianness: .little)
        buffer.writeInteger(flag, endianness: .little)
        buffer.writeInteger(serviceId, endianness: .little)
        buffer.writeInteger(clientId, endianness: .little)
    }
    
}

struct QMITransactionHeader {
    let serviceCtl: Bool
    var byteCount: Int {
        get {
            return serviceCtl ? 2 : 3
        }
    }
    
    let compound: Bool
    let response: Bool
    let indication: Bool
    let transactionId: UInt16
    
    fileprivate init(nsData: Data) throws {
        let data = BinaryData(data: nsData, bigEndian: false)
        
        // The transaction header holds a one-byte bitfield and
        // a two- or three-byte transaction id for identifying related packets.
        
        let transactionBitfield: UInt8 = try data.get(0)
        
        // Based on the header's length the bitfield contains different information.
        if nsData.count == 2 {
            // QMI packets of the 0x00 (CTL) service only have a two-byte transaction header
            serviceCtl = true
            
            compound = false
            response = transactionBitfield & 0b00000001 != 0
            indication = transactionBitfield & 0b00000010 != 0
            
            let tmpTransactionId: UInt8 = try data.get(1)
            transactionId = UInt16(tmpTransactionId)
        } else {
            // QMI packets of other services have a three-byte transaction header
            serviceCtl = false
            
            compound = transactionBitfield & 0b00000001 != 0
            response = transactionBitfield & 0b00000010 != 0
            indication = transactionBitfield & 0b00000100 != 0
            
            transactionId = try data.get(1)
        }
    }
    
    fileprivate init(response: Bool, indication: Bool, transactionId: UInt8) {
        self.serviceCtl = true
        
        self.compound = false
        self.response = response
        self.indication = indication
        self.transactionId = UInt16(transactionId)
    }
    
    fileprivate init(compound: Bool, response: Bool, indication: Bool, transactionId: UInt16) {
        self.serviceCtl = false
        
        self.compound = compound
        self.response = response
        self.indication = indication
        self.transactionId = transactionId
    }
    
    fileprivate func write(buffer: inout ByteBuffer) {
        // Create and write the bitfield
        var transactionBitfield = UInt8(0)
        
        if indication {
            transactionBitfield += 1
        }
        transactionBitfield = transactionBitfield << 1
        
        if response {
            transactionBitfield += 1
        }
        
        if !serviceCtl {
            transactionBitfield = transactionBitfield << 1
            transactionBitfield += compound ? 1 : 0
        }
        
        buffer.writeInteger(transactionBitfield)
        
        // Write one or two bytes of transaction id depending on the service id
        if serviceCtl {
            buffer.writeInteger(UInt8(transactionId), endianness: .little)
        } else {
            buffer.writeInteger(transactionId, endianness: .little)
        }
    }
}

struct QMIMessageHeader {
    let byteCount = 4
    
    let messageId: UInt16
    let messageLength: UInt16
    
    fileprivate init(nsData: Data) throws {
        let data = BinaryData(data: nsData, bigEndian: false)
        
        // The message holds information about the packet's content length and its function.
        
        // The combination of the service id and the two-byte message id assign each packet its function.
        messageId = try data.get(0)
        // The two-byte message length only counts the TLV bytes
        messageLength = try data.get(2)
    }
    
    fileprivate init(messageId: UInt16, messageLength: UInt16) {
        self.messageId = messageId
        self.messageLength = messageLength
    }
    
    fileprivate func write(buffer: inout ByteBuffer) {
        buffer.writeInteger(messageId, endianness: .little)
        buffer.writeInteger(messageLength, endianness: .little)
    }
}

struct QMITLV {
    var byteCount: Int {
        return 1 + 2 + Int(length)
    }
    
    let type: UInt8
    let length: UInt16
    let data: Data
    
    fileprivate init(nsData: Data) throws {
        let data = BinaryData(data: nsData, bigEndian: false)
        
        // Type-Length-Value (TLV) elements have a three-byte header that defines their variable data size.
        
        // The one-byte type
        type = try data.get(0)
        // The two-byte length of the following data
        length = try data.get(1)
        // The actual content of the TLV
        self.data = nsData.subdata(in: 3..<1+2+Int(length))
    }
    
    init(type: UInt8, data: Data) throws {
        self.type = type
        if data.count >= UInt16.max {
            throw QMIGenerationError.DataTooLong(max: Int(UInt16.max), length: data.count)
        }
        self.length = UInt16(data.count)
        self.data = data
    }
    
    fileprivate func write(buffer: inout ByteBuffer) {
        buffer.writeInteger(type, endianness: .little)
        buffer.writeInteger(length, endianness: .little)
        buffer.writeBytes(data)
    }
}
