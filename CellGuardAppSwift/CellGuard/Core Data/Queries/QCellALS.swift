//
//  ALS.swift
//  CellGuard
//
//  Created by Lukas Arnold on 04.05.24.
//

import CoreData
import Foundation

extension PersistenceController {

    /// Imports ALS cells into the Core Data store on a private queue.
    func importALSCells(from cells: [ALSQueryCell]) throws {
        try performAndWait(name: "importContext", author: "importALSCells") { context in
            let importedDate = Date()

            // We can't use a BatchInsertRequest because it doesn't support relationships
            // See: https://developer.apple.com/forums/thread/676651
            cells.forEach { queryCell in
                // Check if the ALS cell already exists and only update its attributes in that case
                let existFetchRequest = CellALS.fetchRequest()
                existFetchRequest.fetchLimit = 1
                existFetchRequest.predicate = sameCellPredicate(queryCell: queryCell)
                do {
                    // If the cell exists, we update its attributes but not its location.
                    // This is crucial for adding the PCI & EARFCN to an existing LTE cell.
                    let existingCell = try context.fetch(existFetchRequest).first
                    if let existingCell = existingCell {
                        existingCell.imported = importedDate
                        queryCell.applyTo(alsCell: existingCell)
                        return
                    }
                } catch {
                    logger.warning("Can't check if ALS cells (\(queryCell)) already exists: \(error)")
                    return
                }

                // The cell does not exists in our app's database, so we can add it
                let cell = CellALS(context: context)
                cell.imported = importedDate
                queryCell.applyTo(alsCell: cell)

                if let queryLocation = queryCell.location {
                    let location = LocationALS(context: context)
                    queryLocation.applyTo(location: location)
                    cell.location = location
                } else {
                    logger.warning("Imported an ALS cell without a location: \(queryCell)")
                }
            }

            // Save the task context
            try context.save()
            logger.debug("Successfully inserted \(cells.count) ALS cells.")
        }
    }

    func assignExistingALSIfPossible(to tweakCellID: NSManagedObjectID) throws -> NSManagedObjectID? {
        return try performAndWait(name: "updateContext", author: "assignExistingALSIfPossible") { context -> NSManagedObjectID? in
            // Get the tweak cell object.
            guard let tweakCell = context.object(with: tweakCellID) as? CellTweak else {
                return nil
            }

            // Find an ALS cell with the same attributes as the cell.
            guard let alsCell = try fetchALSCell(from: tweakCell, context: context) else {
                return nil
            }

            // If found, store this in the cell's attributes, save the it, and return the cell's object ID.
            tweakCell.appleDatabase = alsCell
            try context.save()
            return alsCell.objectID
        }
    }

    private func fetchALSCell(from tweakCell: CellTweak, context: NSManagedObjectContext) throws -> CellALS? {
        let fetchRequest = NSFetchRequest<CellALS>()
        fetchRequest.entity = CellALS.entity()
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = sameCellPredicate(cell: tweakCell)

        do {
            let result = try fetchRequest.execute()
            return result.first
        } catch {
            logger.warning("Can't fetch ALS cell for tweak cell (\(tweakCell)): \(error)")
            throw error
        }
    }

    static func queryCell(from cell: CellTweak) -> ALSQueryCell {
        return ALSQueryCell(
            technology: ALSTechnology(rawValue: cell.technology ?? "") ?? .OFF,
            country: cell.country,
            network: cell.network,
            area: cell.area,
            cell: cell.cell
        )
    }

    func sameCellPredicate(cell: Cell, prefix: String = "") -> NSPredicate {
        return NSPredicate(
            format: "\(prefix)technology = %@ and \(prefix)country = %@ and \(prefix)network = %@ and \(prefix)area = %@ and \(prefix)cell = %@",
            cell.technology ?? "", cell.country as NSNumber, cell.network as NSNumber,
            cell.area as NSNumber, cell.cell as NSNumber
        )
    }

    func sameCellPredicate(queryCell cell: ALSQueryCell) -> NSPredicate {
        return NSPredicate(
            format: "technology = %@ and country = %@ and network = %@ and area = %@ and cell = %@",
            cell.technology.rawValue, cell.country as NSNumber, cell.network as NSNumber,
            cell.area as NSNumber, cell.cell as NSNumber
        )
    }

    /// Calculates the distance between the location for the tweak cell and its verified counter part from Apple's database.
    /// If no verification or locations references cell exist, nil is returned.
    func calculateDistance(tweakCell tweakCellID: NSManagedObjectID) -> (CellLocationDistance, NSManagedObjectID, NSManagedObjectID)? {
        return try? performAndWait(name: "fetchContext", author: "calculateDistance") { (context) -> (CellLocationDistance, NSManagedObjectID, NSManagedObjectID)? in
            guard let tweakCell = context.object(with: tweakCellID) as? CellTweak else {
                logger.warning("Can't calculate distance for cell \(tweakCellID): Cell missing from task context")
                return nil
            }

            guard let alsCell = tweakCell.appleDatabase else {
                logger.warning("Can't calculate distance for cell \(tweakCellID): No verification ALS cell")
                return nil
            }

            guard let userLocation = tweakCell.location else {
                logger.warning("Can't calculate distance for cell \(tweakCellID): Missing user location from cell")
                return nil
            }

            guard let alsLocation = alsCell.location else {
                // TODO: Sometimes this does not work ): -> imported = nil, other properties are there
                logger.warning("Can't calculate distance for cell \(tweakCellID): Missing location from ALS cell")
                return nil
            }

            let distance = CellLocationDistance.distance(userLocation: userLocation, alsLocation: alsLocation)
            return (distance, userLocation.objectID, alsCell.objectID)
        }
    }

}
