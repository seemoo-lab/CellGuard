//
//  PacketConstants.swift
//  CellGuard
//
//  Created by Lukas Arnold on 20.11.23.
//

import Foundation

struct PacketConstants {
    
    static let ariRejectDirection = CPTDirection.ingoing
    static let ariRejectGroup = 7
    static let ariRejectType = 769
    
    static let ariSignalDirection = CPTDirection.ingoing
    static let ariSignalGroup = 9
    static let ariSignalType = 772
    
    static let qmiRejectDirection = CPTDirection.ingoing
    static let qmiRejectIndication = true
    static let qmiRejectService = 0x03
    static let qmiRejectMessage = 0x0068
    
    static let qmiSignalDirection = CPTDirection.ingoing
    static let qmiSignalIndication = true
    static let qmiSignalService = 0x03
    static let qmiSignalMessage = 0x0051
    
    static let qmiCellInfoService = 0x03
    static let qmiCellInfoMessage = 0x5556
    static let qmiCellInfoTechnologies: [ALSTechnologyVersion] = [.cdma1x, .cdmaEvdo, .umts, .tdscdma, .gsm, .lteV1, .lteV2, .lteV3, .lteV4, .nrV2, .nrV3]
    static let qmiTLVTypes: [ALSTechnologyVersion: UInt8] = [
        .cdma1x: 0xa1, .cdmaEvdo: 0xa2, .umts: 0xb7, .tdscdma: 0xd0, .gsm: 0xb8,
        .lteV1: 0xbb, .lteV2: 0xbc, .lteV3: 0xd2, .lteV4: 0xd3, .nrV2: 0xe2, .nrV3: 0xe4
    ]

}
