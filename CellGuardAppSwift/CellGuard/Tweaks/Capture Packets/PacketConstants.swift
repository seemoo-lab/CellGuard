//
//  PacketConstants.swift
//  CellGuard
//
//  Created by Lukas Arnold on 20.11.23.
//

import Foundation

struct ARIKey: Hashable {
    let type: UInt16
    let technology: ALSTechnologyVersion
}

struct PacketConstants {

    static let ariRejectDirection = CPTDirection.ingoing
    static let ariRejectGroup = 7
    static let ariRejectType = 769

    static let ariSignalDirection = CPTDirection.ingoing
    static let ariSignalGroup = 9
    static let ariSignalType = 772

    static let ariInstanceTlvId: UInt8 = 1

    static let ariCellInfoDirection = CPTDirection.ingoing
    static let ariCellInfoGroup = 9
    // IBINetGetCellInfoRespCb, IBINetGetCellInfoRespCbV1, IBINetGetCellInfoIndCb, IBINetGetCellInfoIndCbV1
    static let ariCellInfoTypes: [UInt16] = [519, 521, 775, 776]
    static let ariCellInfoTechnologies: [ALSTechnologyVersion] = [.cdma1x, .cdmaEvdo, .umts, .tdscdma, .gsm, .lte, .lteV1T, .lteR15, .lteR15V2, .nr, .nrV2]
    static let ariCellInfoTLVTypes: [ARIKey: UInt8] = [
        ARIKey(type: 519, technology: .cdma1x): 34, ARIKey(type: 519, technology: .cdmaEvdo): 37,
        ARIKey(type: 519, technology: .umts): 10, ARIKey(type: 519, technology: .gsm): 13,
        ARIKey(type: 519, technology: .lte): 16, ARIKey(type: 519, technology: .lteV1T): 50,
        ARIKey(type: 519, technology: .lteR15): 52, ARIKey(type: 519, technology: .tdscdma): 28,
        ARIKey(type: 519, technology: .lteR15V2): 57, ARIKey(type: 519, technology: .nr): 54,
        ARIKey(type: 519, technology: .nrV2): 59,
        ARIKey(type: 521, technology: .cdma1x): 22, ARIKey(type: 521, technology: .cdmaEvdo): 23,
        ARIKey(type: 521, technology: .umts): 7, ARIKey(type: 521, technology: .gsm): 9,
        ARIKey(type: 521, technology: .lte): 11, ARIKey(type: 521, technology: .lteV1T): 28,
        ARIKey(type: 521, technology: .tdscdma): 19,
        ARIKey(type: 775, technology: .cdma1x): 32, ARIKey(type: 775, technology: .cdmaEvdo): 35,
        ARIKey(type: 775, technology: .umts): 8, ARIKey(type: 775, technology: .gsm): 11,
        ARIKey(type: 775, technology: .lte): 14, ARIKey(type: 775, technology: .lteV1T): 42,
        ARIKey(type: 775, technology: .lteR15): 44, ARIKey(type: 775, technology: .tdscdma): 26,
        ARIKey(type: 775, technology: .lteR15V2): 49, ARIKey(type: 775, technology: .nr): 46,
        ARIKey(type: 775, technology: .nrV2): 51,
        ARIKey(type: 776, technology: .cdma1x): 20, ARIKey(type: 776, technology: .cdmaEvdo): 21,
        ARIKey(type: 776, technology: .umts): 5, ARIKey(type: 776, technology: .gsm): 7,
        ARIKey(type: 776, technology: .lte): 9, ARIKey(type: 776, technology: .lteV1T): 26,
        ARIKey(type: 776, technology: .tdscdma): 17
    ]

    static let qmiRejectDirection = CPTDirection.ingoing
    static let qmiRejectIndication = true
    static let qmiRejectService = 0x03
    static let qmiRejectMessage = 0x0068

    static let qmiSignalDirection = CPTDirection.ingoing
    static let qmiSignalIndication = true
    static let qmiSignalService = 0x03
    static let qmiSignalMessage = 0x0051

    static let qmiCellInfoDirection = CPTDirection.ingoing
    static let qmiCellInfoService = 0x03
    static let qmiCellInfoMessage = 0x5556
    static let qmiCellInfoTechnologies: [ALSTechnologyVersion] = [.cdma1x, .cdmaEvdo, .umts, .tdscdma, .gsm, .lteV1, .lteV2, .lteV3, .lteV4, .nr, .nrV2, .nrV3]
    static let qmiCellInfoTLVTypes: [ALSTechnologyVersion: UInt8] = [
        .cdma1x: 0xa1, .cdmaEvdo: 0xa2, .umts: 0xb7, .tdscdma: 0xd0, .gsm: 0xb8,
        .lteV1: 0xbb, .lteV2: 0xbc, .lteV3: 0xd2, .lteV4: 0xd3, .nr: 0xe0, .nrV2: 0xe2, .nrV3: 0xe4
    ]

}

func ariMsgHasInstance(group: UInt8, type: UInt16) -> Bool {
    switch group {
    case 2, 4, 5, 6, 8, 10, 11, 12, 13, 14, 16, 19, 21, 29, 31, 33:
        return true
    case 20, 22, 23, 34, 51, 54, 60, 61, 62, 63:
        return false
    case 1:
        return [257, 258, 265, 274, 513, 514, 521, 530].contains(type)
    case 3:
        return ![330, 586].contains(type)
    case 7:
        return ![278, 279, 534, 535, 545].contains(type)
    case 9:
        return ![293, 294, 298, 550, 554].contains(type)
    case 15:
        return [257, 261, 262, 264, 265, 513, 517, 518, 520, 521, 769, 773].contains(type)
    case 17:
        return [263, 266, 268, 519, 522, 524].contains(type)
    case 18:
        return ![265, 266, 521, 522].contains(type)
    case 42:
        return [257, 258, 513].contains(type)
    case 50:
        return ![273, 275, 276, 277, 278, 529, 531, 532, 533, 534, 771, 773, 774, 775].contains(type)
    default:
        return false
    }
}
