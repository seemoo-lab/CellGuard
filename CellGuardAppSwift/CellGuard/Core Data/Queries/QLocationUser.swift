//
//  LocationUser.swift
//  CellGuard
//
//  Created by Lukas Arnold on 04.05.24.
//

import CoreData
import Foundation

extension PersistenceController {

    /// Uses `NSBatchInsertRequest` (BIR) to import locations into the Core Data store on a private queue.
    func importUserLocations(from locations: [TrackedUserLocation]) throws {
        // TODO: Only import if the location is different by a margin with the last location

        try performAndWait(name: "importContext", author: "importLocations") { context in
            var index = 0
            let total = locations.count

            let importedDate = Date()

            let batchInsertRequest = NSBatchInsertRequest(entity: LocationUser.entity(), managedObjectHandler: { location in
                guard index < total else { return true }

                if let location = location as? LocationUser {
                    locations[index].applyTo(location: location)
                    location.imported = importedDate
                }

                index += 1
                return false
            })

            let fetchResult = try context.execute(batchInsertRequest)

            if let batchInsertResult = fetchResult as? NSBatchInsertResult,
               !((batchInsertResult.result as? Bool) ?? false) {
                logger.debug("Failed to execute batch import request for user locations.")
                throw PersistenceError.batchInsertError
            }
        }

        logger.debug("Successfully inserted \(locations.count) locations.")
    }

    func assignLocation(to tweakCellID: NSManagedObjectID) throws -> (Bool, Date?) {
        let taskContext = newTaskContext()

        var saveError: Error?
        var foundLocation: Bool = false
        var cellCollected: Date?

        taskContext.performAndWait {
            guard let tweakCell = taskContext.object(with: tweakCellID) as? CellTweak else {
                logger.warning("Can't assign location to the tweak cell with object ID: \(tweakCellID)")
                saveError = PersistenceError.objectIdNotFoundError
                return
            }

            cellCollected = tweakCell.collected

            // Find the most precise user location within a four minute window
            let fetchLocationRequest = NSFetchRequest<LocationUser>()
            fetchLocationRequest.entity = LocationUser.entity()
            // We don't set a fetch limit as it interferes the following predicate
            if let cellCollected = cellCollected {
                let before = cellCollected.addingTimeInterval(-120)
                let after = cellCollected.addingTimeInterval(120)

                fetchLocationRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "collected != nil"),
                    NSPredicate(format: "collected > %@", before as NSDate),
                    NSPredicate(format: "collected < %@", after as NSDate)
                ])
            } else {
                // No location without a date boundary as we would just pick a random location
                return
            }
            fetchLocationRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \LocationUser.horizontalAccuracy, ascending: true)
            ]

            // Execute the fetch request
            let locations: [LocationUser]
            do {
                locations = try fetchLocationRequest.execute()
            } catch {
                logger.warning("Can't query location for tweak cell \(tweakCell): \(error)")
                saveError = error
                return
            }

            // Return with foundLocation = false if we've found no location matching the criteria
            guard let location = locations.first else {
                return
            }

            // We've found a location, assign it to the cell, and save the cell
            foundLocation = true
            tweakCell.location = location

            do {
                try taskContext.save()
            } catch {
                logger.warning("Can't save tweak cell (\(tweakCell)) with an assigned location: \(error)")
                saveError = error
                return
            }
        }
        if let saveError = saveError {
            throw saveError
        }

        return (foundLocation, cellCollected)
    }

    func deleteLocationsOlderThan(days: Int) {
        let taskContext = newTaskContext()
        logger.debug("Start deleting locations older than \(days) day(s) from the store...")

        taskContext.performAndWait {
            do {
                let startOfDay = Calendar.current.startOfDay(for: Date())
                guard let daysAgo = Calendar.current.date(byAdding: .day, value: -days, to: startOfDay) else {
                    logger.debug("Can't calculate the date for location deletion")
                    return
                }
                logger.debug("Deleting locations older than \(startOfDay)")
                // Only delete old locations not referenced by any cells
                let predicate = NSPredicate(format: "collected < %@ and cells.@count == 0", daysAgo as NSDate)

                let count = try deleteData(entity: LocationUser.entity(), predicate: predicate, context: taskContext)
                logger.debug("Successfully deleted \(count) old locations")
            } catch {
                logger.warning("Failed to delete old locations: \(error)")
            }
        }
    }

}
