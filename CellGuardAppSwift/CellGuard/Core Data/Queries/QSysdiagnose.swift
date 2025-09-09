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

    func fetchSysdiagnoseDateRange() async -> ClosedRange<Date>? {
        return try? performAndWait(name: "fetchContext", author: "fetchSysdiagnoseDateRange") {_ in
            let firstReq: NSFetchRequest<Sysdiagnose> = Sysdiagnose.fetchRequest()
            firstReq.fetchLimit = 1
            firstReq.sortDescriptors = [NSSortDescriptor(keyPath: \Sysdiagnose.imported, ascending: true)]
            firstReq.propertiesToFetch = ["imported"]
            firstReq.includesSubentities = false

            let lastReq: NSFetchRequest<Sysdiagnose> = Sysdiagnose.fetchRequest()
            lastReq.fetchLimit = 1
            lastReq.sortDescriptors = [NSSortDescriptor(keyPath: \Sysdiagnose.imported, ascending: false)]
            lastReq.propertiesToFetch = ["imported"]
            lastReq.includesSubentities = false

            let firstEvent = try firstReq.execute()
            let lastEvent = try lastReq.execute()

            guard let firstEvent = firstEvent.first, let lastEvent = lastEvent.first else {
                return Date.distantPast...Date.distantFuture
            }

            return (firstEvent.imported ?? Date.distantPast)...(lastEvent.imported ?? Date.distantFuture)
        }
    }

}
