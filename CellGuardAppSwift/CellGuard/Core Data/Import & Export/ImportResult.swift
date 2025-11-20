//
//  ImportResult.swift
//  CellGuard
//
//  Created by Lukas Arnold on 10.04.24.
//

import Foundation

enum ImportNotice: Identifiable {
    case logTruncatedDueToFullDisk
    case cellParserMisalignment
    case sysdiagnoseSize

    var id: Self { self }

    var text: String {
        switch self {
        case .logTruncatedDueToFullDisk:
            return "Make sure you have enough free storage on your iPhone, otherwise logs are truncated more frequently."
        case .cellParserMisalignment:
            return "Please report this sysdiagnose. The Packet Cell Parser differs from the Log Cell Parser. Your imported data would help us to improve CellGuard. Please open an issue on github.com/seemoo-lab/CellGuard/issues to arrange a channel for reporting the sysdiagnose."
        case .sysdiagnoseSize:
            return "Make sure to import a valid system diagnose. Their usual file size is between 100 MB and 1 GB."
        }
    }
}

struct ImportCount: Equatable, Hashable {
    let count: Int
    let first: Date?
    let last: Date?
}

struct ImportResult {
    let cells: ImportCount?
    let alsCells: ImportCount?
    let locations: ImportCount?
    let packets: ImportCount?
    let connectivityEvents: ImportCount?
    let sysdiagnoses: ImportCount?

    let notices: [ImportNotice]
}
