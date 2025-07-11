//
//  GroupedConnectivityEvents.swift
//  CellGuard
//
//  Created by mp on 11.07.25.
//

import Foundation

enum GroupedConnectivityEventsError: Error {
    case emptyList
    case missingStartDate
    case missingEndDate
}

struct GroupedConnectivityEvents: Identifiable {

    let settings: ConnectivityListFilterSettings
    let events: [ConnectivityEvent]
    let start: Date
    let end: Date
    let id: Int

    init(events: [ConnectivityEvent], settings: ConnectivityListFilterSettings) throws {
        // We require that the list contains at least one element
        if events.isEmpty {
            throw GroupedConnectivityEventsError.emptyList
        }
        self.events = events
        self.settings = settings

        // We assume the measurements are sorted in descending order based on their timestamp
        guard let end = events.first?.collected else {
            throw GroupedConnectivityEventsError.missingEndDate
        }
        guard let start = events.last?.collected else {
            throw GroupedConnectivityEventsError.missingStartDate
        }
        self.start = start
        self.end = end

        self.id = events.reduce(0, { (pref, event) in pref &+ event.objectID.hashValue })
    }

    func detailsPredicate() -> NSPredicate {
        return NSCompoundPredicate(
            andPredicateWithSubpredicates: settings.predicates(startDate: start, endDate: end)
        )
    }

}
