//
//  Cell.swift
//  CellGuard
//
//  Created by Lukas Arnold on 11.04.24.
//

import Foundation

public protocol Cell {
    
    var technology: String? {get set}
    var country: Int32 {get set}
    var network: Int32 {get set}
    var cell: Int64 {get set}
    var area: Int32 {get set}
    
    var imported: Date? {get set}
}
