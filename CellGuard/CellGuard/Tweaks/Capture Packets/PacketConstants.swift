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
    
}
