//
//  NavObjectId.swift
//  CellGuard
//
//  Created by Lukas Arnold on 20.06.25.
//

import Foundation
import CoreData

struct NavObjectId<T: NSManagedObject>: Hashable {

    let id: NSManagedObjectID

    init(id: NSManagedObjectID) {
        self.id = id
    }

    init(object: T) {
        self.id = object.objectID
    }

    var object: T {
        // TODO: The object might might not exist ?
        PersistenceController.shared.container.viewContext.object(with: id) as! T
    }

}
