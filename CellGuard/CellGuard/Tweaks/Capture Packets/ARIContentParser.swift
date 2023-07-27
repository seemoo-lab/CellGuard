//
//  ARIContentParser.swift
//  CellGuard
//
//  Created by Lukas Arnold on 26.07.23.
//

import Foundation
import BinarySwift

enum ParsedContentARIPacketError: Error  {
    case wrongGroupId
    case wrongTypeId
    case tlvMissing(id: Int)
}

struct ParsedARIRadioSignalIndication {
    
    // TODO: What units are in use here? Are these RSSI / ?? values
    let signalStrength: Int8
    let signalQuality: Int8
    let signalStrengthMax: Int32
    let signalQualityMax: Int32
    
    init(ariPacket: ParsedARIPacket) throws {
        // The IBINetRadioSignalIndCb packet is part of the 09_net_cell group
        if ariPacket.header.group != 9 {
            throw ParsedContentARIPacketError.wrongGroupId
        }
        
        // The IBINetRadioSignalIndCb packet has the type id 772 (0x304)
        if ariPacket.header.type != 772 {
            throw ParsedContentARIPacketError.wrongTypeId
        }
        
        let extractInt8: (Int) throws -> Int8 = { tlvId in
            guard let tlv = ariPacket.tlvs.first(where: { $0.type == tlvId }) else {
                throw ParsedContentARIPacketError.tlvMissing(id: tlvId)
            }
            
            return try BinaryData(data: tlv.data).get(0)
        }
        
        let extractInt32: (Int) throws -> Int32 = { tlvId in
            guard let tlv = ariPacket.tlvs.first(where: { $0.type == tlvId }) else {
                throw ParsedContentARIPacketError.tlvMissing(id: tlvId)
            }
            
            return try BinaryData(data: tlv.data).get(0)
        }
        
        signalStrength = try extractInt8(2)
        signalQuality = try extractInt8(3)
        signalStrengthMax = try extractInt32(4)
        signalQualityMax = try extractInt32(5)
    }
    
}
