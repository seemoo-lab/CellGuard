//
//  QSysdiagnose.swift
//  CellGuard
//
//  Created by mp on 30.08.25.
//

import CoreData
import Foundation

extension PersistenceController {

    /// Import SysdiagnoseMetadata into the Core Data store on a private queue.
    func importSysdiagnoseMetadata(from metadata: SysdiagnoseMetadata) throws -> NSManagedObjectID? {
        return try performAndWait(name: "importContext", author: "importSysdiagnose") { context in
            context.mergePolicy = NSMergePolicy.rollback

            let sysdiagnose = Sysdiagnose(context: context)
            metadata.applyTo(sysdiagnose)
            try context.save()

            logger.debug("Successfully inserted sysdiagnose.")
            return sysdiagnose.objectID
        }
    }

    /// Import SysdiagnoseMetadata into the Core Data store on a private queue.
    func fetchSysdiagnose(archiveIdentifier: String) throws -> Sysdiagnose? {
        return try performAndWait(name: "fetchContext", author: "fetchSysdiagnose") { _ in
            let fetchRequest = NSFetchRequest<Sysdiagnose>()
            fetchRequest.entity = Sysdiagnose.entity()
            fetchRequest.fetchLimit = 1
            fetchRequest.predicate = NSPredicate(format: "archiveIdentifier = %@", archiveIdentifier as NSString)

            do {
                let result = try fetchRequest.execute()
                return result.first
            } catch {
                logger.warning("Can't fetch Sysdiagnose for archiveIdentifier (\(archiveIdentifier)): \(error)")
                throw error
            }
        }
    }
}
