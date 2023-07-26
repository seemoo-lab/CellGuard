//
//  CellStatus.swift
//  CellGuard
//
//  Created by Lukas Arnold on 16.01.23.
//

import Foundation

enum CellStatus: String, Comparable {
    case imported
    case processedCell
    case processedLocation
    // case processedPacket
    case processedRejectPacket
    case verified
    
    func humanDescription() -> String {
        switch (self) {
        case .imported: return "Pending Verification"
        case .processedCell: return "Pending Location Verification"
        case .processedLocation: return "Pending Packet Verification"
        case .processedRejectPacket: return "Pending Signal Strength Verification"
        case .verified: return "Verification Complete"
        }
    }
    
    func numericStage() -> Int {
        switch (self) {
        case .imported: return 0
        case .processedCell: return 1
        case .processedLocation: return 2
        case .processedRejectPacket: return 3
        case .verified: return 4
        }
    }
    
    static func < (lhs: CellStatus, rhs: CellStatus) -> Bool {
        return lhs.numericStage() < rhs.numericStage()
    }
}
