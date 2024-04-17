//
//  ImportResult.swift
//  CellGuard
//
//  Created by Lukas Arnold on 10.04.24.
//

import Foundation

enum ImportNotice: Identifiable {
    case profileNewlyInstalled
    case profileNotInstalled
    case profileExpired
    case profileUnknownStatus
    case logTruncatedDueToFullDisk
    
    var id: Self { self }
    
    var text: String {
        switch (self) {
        case .profileNewlyInstalled:
            return "The baseband profile was installed recently, thus only a limited amount of data is available."
        case .profileNotInstalled:
            return "Please make sure the baseband profile is installed on this iPhone, otherwise CellGuard cannot collect data. The profile expires after 21 days."
        case .profileExpired:
            return "The baseband profile recently expired. Please re-install it to continue recording data."
        case .profileUnknownStatus:
            return "Please verify that you've installed the baseband profile. If not installed, you cannot import data."
        case .logTruncatedDueToFullDisk:
            return "Please make sure you have enough free storage on your iPhone, otherwise logs are truncated more frequently."
        }
    }
}

struct ImportCount: Equatable {
    let count: Int
    let first: Date?
    let last: Date?
}

struct ImportResult {
    let cells: ImportCount?
    let alsCells: ImportCount?
    let locations: ImportCount?
    let packets: ImportCount?
    
    let notices: [ImportNotice]
}
