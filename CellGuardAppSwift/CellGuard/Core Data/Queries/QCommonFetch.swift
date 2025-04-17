//
//  CommonFetch.swift
//  CellGuard
//
//  Created by Lukas Arnold on 04.05.24.
//

import CoreData
import Foundation

extension PersistenceController {

    func countEntitiesOf<T>(_ request: NSFetchRequest<T>) -> Int? {
        let taskContext = newTaskContext()

        // We can skip loading all the sub-entities
        // See: https://stackoverflow.com/a/1134353
        request.includesSubentities = false

        var count: Int?
        taskContext.performAndWait {
            do {
                count = try taskContext.count(for: request)
            } catch {
                logger.warning("Can't count the number of entities in the database for \(request)")
            }
        }

        return count
    }

}
