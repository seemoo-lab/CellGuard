//
//  Deletion.swift
//  CellGuard
//
//  Created by Lukas Arnold on 04.05.24.
//

import CoreData
import Foundation

extension PersistenceController {

    func deleteDataInBackground(categories: [PersistenceCategory], completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Perform the deletion
            let result = Result { try self.deleteData(categories: categories) }

            // Call the callback on the main queue
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    /// Synchronously deletes all records in the Core Data store.
    func deleteData(categories: [PersistenceCategory]) throws {
        let taskContext = newTaskContext()
        logger.debug("Start deleting data of \(categories) from the store...")

        // If the ALS cell cache or older locations are deleted but no connected cells, we do not reset their verification status to trigger a re-verification.
        let categoryEntityMapping: [PersistenceCategory: [NSEntityDescription]] = [
            .connectedCells: [CellTweak.entity()],
            .alsCells: [CellALS.entity(), LocationALS.entity(), VerificationState.entity(), VerificationLog.entity()],
            .locations: [LocationUser.entity()],
            .packets: [PacketARI.entity(), PacketIndexARI.entity(), PacketQMI.entity(), PacketIndexQMI.entity()]
        ]

        var deleteError: Error?
        taskContext.performAndWait {
            do {
                try categoryEntityMapping
                    .filter { categories.contains($0.key) }
                    .flatMap { $0.value }
                    .forEach { entity in
                        _ = try deleteData(entity: entity, predicate: nil, context: taskContext)
                    }
            } catch {
                logger.warning("Failed to delete data: \(error)")
                deleteError = error
            }

            logger.debug("Successfully deleted data of \(categories).")
        }

        if let deleteError = deleteError {
            throw deleteError
        }

        #if JAILBREAK
        if categories.contains(.packets) {
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.mostRecentPacket.rawValue)
        }
        #endif

        cleanPersistentHistoryChanges()
    }

    /// Deletes all records belonging to a given entity
    func deleteData(entity: NSEntityDescription, predicate: NSPredicate?, context: NSManagedObjectContext) throws -> Int {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
        fetchRequest.entity = entity
        if let predicate = predicate {
            fetchRequest.predicate = predicate
        }

        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeCount
        let result = try context.execute(deleteRequest)
        return ((result as? NSBatchDeleteResult)?.result as? Int) ?? 0
    }

}
