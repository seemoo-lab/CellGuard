//
//  Notifications.swift
//  CellGuard
//
//  Created by Lukas Arnold on 04.05.24.
//

import CoreData
import Foundation

extension PersistenceController {
    
    func fetchNotificationCellCounts() -> (suspicious: Int, untrusted: Int)? {
        return try? performAndWait(name: "fetchContext", author: "notificationCellCounts") { context in
            let request: NSFetchRequest<VerificationState> = VerificationState.fetchRequest()
            request.predicate = NSPredicate(
                format: "notification == NO and finished == YES and pipeline == %@ and score < %@",
                Int(primaryVerificationPipeline.id) as NSNumber, Int(primaryVerificationPipeline.pointsSuspicious) as NSNumber
            )
            
            let verificationStates = try context.fetch(request)
            
            // Choose the measurement with the lowest score for each cell
            // TODO: Fix
            let cells = Dictionary(grouping: verificationStates) { verificationState in
                if let cell = verificationState.cell {
                    return Self.queryCell(from: cell)
                } else {
                    // Fallback if there's a relationship missing (should never happen)
                    return ALSQueryCell(technology: .GSM, country: 0, network: 0, area: 0, cell: 0)
                }
            }.compactMap { $0.value.min { $0.score < $1.score } }
            
            // Count the number suspicious and untrusted cells
            let count = (
                cells.filter {$0.score >= primaryVerificationPipeline.pointsUntrusted}.count,
                cells.filter {$0.score < primaryVerificationPipeline.pointsUntrusted}.count
            )
            
            // Update all cells, so no multiple notification are sent
            verificationStates.forEach { $0.notification = true }
            try context.save()
            
            return count
        }
    }
    
}
