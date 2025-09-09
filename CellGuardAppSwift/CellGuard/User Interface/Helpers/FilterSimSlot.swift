//
//  FilterSimSlot.swift
//  CellGuard
//
//  Created by Lukas Arnold on 29.08.25.
//

enum FilterSimSlot: UInt8, CaseIterable, Identifiable {
    case all, slot1, slot2, none

    var id: Self { self }

    var slotNumber: Int? {
        switch self {
        case .slot1:
            return 1
        case .slot2:
            return 2
        case .none:
            return 0
        default:
            return nil
        }
    }
}
