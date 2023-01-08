//
//  PersistenceError.swift
//  CellGuard
//
//  Created by Lukas Arnold on 08.01.23.
//

import Foundation

enum PersistenceError: Error {
    case batchInsertError
    case persistentHistoryChangeError
}
