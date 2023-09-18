//
//  PersistenceCategories.swift
//  CellGuard
//
//  Created by Lukas Arnold on 14.06.23.
//

import Foundation

enum PersistenceCategory: Comparable {
    case info
    case connectedCells
    case alsCells
    case locations
    case packets
    
    func url(directory: URL) -> URL {
        return directory.appendingPathComponent(self.fileName())
    }
    
    func fileName() -> String {
        switch (self) {
        case .info: return "info.json"
        case .connectedCells: return "user-cells.csv"
        case .alsCells: return "als-cells.csv"
        case .locations: return "locations.csv"
        case .packets: return "packets.csv"
        }
    }
}
