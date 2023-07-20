//
//  CellStatus.swift
//  CellGuard
//
//  Created by Lukas Arnold on 16.01.23.
//

import Foundation

enum CellStatus: String {
    case imported
    case processedCell
    case processedLocation
    // case processedPacket
    case verified
    
    func humanDescription() -> String {
        switch (self) {
        case .imported: return "Pending Verification"
        case .processedCell: return "Verified Cell"
        case .processedLocation: return "Verified Location"
        // case .processedPacket: return "Verified Packet"
        case .verified: return "Verification Complete"
        }
    }
}
