//
//  CellStatus.swift
//  CellGuard
//
//  Created by Lukas Arnold on 16.01.23.
//

import Foundation

enum CellStatus: String {
    case imported
    case verified
    case failed
    
    func humanDescription() -> String {
        switch (self) {
        case .imported: return "Pending"
        case .verified: return "Verified"
        case .failed: return "Failed"
        }
    }
}
