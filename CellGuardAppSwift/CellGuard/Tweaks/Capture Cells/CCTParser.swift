//
//  CCTParser.swift
//  CellGuard
//
//  Created by Lukas Arnold on 01.01.23.
//

import Foundation
import CoreData

enum CCTParserError: Error {
    case emptySample(CellSample)
    case noCells(CellSample)
    case noServingCell(CellSample)
    case invalidTimestamp(CellInfo)
    case invalidSimSlotID(CellInfo)
    case missingRat(ParsedPacket)
    case missingRatOld(CellInfo)
    case unknownRat(String)
    case notImplementedRat(String)
    case missingCellType(CellInfo)
    case unknownCellType(String)
    case invalidQmiService
    case invalidAriGroup
    case invalidQmiMessage
    case invalidAriMessage
    case invalidQmiDirection
    case noQmiLteCellInformation(ParsedQMIPacket)
    case unexpectedTlvLength
}

enum CCTCellType: String {
    case Serving = "CellTypeServing"
    case Neighbor = "CellTypeNeighbor"
    case Monitor = "CellTypeMonitor"
    case Detected = "CellTypeDetected"
}

/// A structure similar to the model "Cell".
struct CCTCellProperties {
    
    var mcc: Int32?
    var network: Int32?
    var area: Int32?
    var cellId: Int64?
    var physicalCellId: Int32?
    
    var technology: ALSTechnology?
    var preciseTechnology: String?
    var frequency: Int32?
    var band: Int32?
    var bandwidth: Int32?
    var deploymentType: Int32?
    
    var timestamp: Date?
    var simSlotID: UInt8?
    
    // applyTo does not set the packetQmi or packetAri because NSBatchInsertRequest does not set relationships.
    func applyTo(tweakCell: CellTweak) {
        tweakCell.country = self.mcc ?? 0
        tweakCell.network = self.network ?? 0
        tweakCell.area = self.area ?? 0
        tweakCell.cell = self.cellId ?? 0
        
        tweakCell.technology = (self.technology ?? .LTE).rawValue
        tweakCell.preciseTechnology = self.preciseTechnology
        
        tweakCell.frequency = self.frequency ?? 0
        tweakCell.band = self.band ?? 0
        tweakCell.bandwidth = self.bandwidth ?? 0
        tweakCell.physicalCell = self.physicalCellId ?? 0
        
        tweakCell.collected = self.timestamp
        tweakCell.simSlotID = self.simSlotID != nil ? Int16(self.simSlotID!) : 0
    }

    func isEqualExceptTime(other: CCTCellProperties?) -> Bool {
        guard let other = other else {
            return false
        }

        return (
            self.mcc == other.mcc &&
            self.network == other.network &&
            self.area == other.area &&
            self.cellId == other.cellId &&
            self.physicalCellId == other.physicalCellId &&
            self.technology == other.technology &&
            self.preciseTechnology == other.preciseTechnology &&
            self.frequency == other.frequency &&
            self.band == other.band &&
            self.bandwidth == other.bandwidth &&
            self.deploymentType == other.deploymentType
        )
    }

    func isMissingKeyProperties() -> Bool {
        let isMissingMCC = (self.mcc ?? 0) == 0
        let isMissingNetwork = (self.network ?? 0) == 0
        let isMissingArea = (self.area ?? 0) == 0
        let isMissingCellId = (self.cellId ?? 0) == 0
        return isMissingMCC || isMissingNetwork || isMissingArea || isMissingCellId
    }

}

struct CCTParser {
    // We currently support 3 Cell Parsers: ARI, QMI, and the Syslog text format.
    // You can find them in their individual files.
}
