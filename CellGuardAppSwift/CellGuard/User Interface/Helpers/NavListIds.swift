//
//  NavListIds.swift
//  CellGuard
//
//  Created by Lukas Arnold on 29.08.25.
//

import Foundation
import CoreData
import SwiftUI

struct NavListIds<T: NSManagedObject>: Hashable {

    let ids: [NSManagedObjectID]

    init(ids: [NSManagedObjectID]) {
        self.ids = ids
    }

    init(objects: [T]) {
        self.ids = objects.map { $0.objectID }
    }

    var objects: [T] {
        // The object might got removed while the new view was built
        let viewContext = PersistenceController.basedOnEnvironment().container.viewContext
        return ids.compactMap { viewContext.object(with: $0) as? T }
    }

    @ViewBuilder
    func ensure<Children: View>(@ViewBuilder children: (_ objects: [T]) -> Children) -> some View {
        let objects = self.objects
        if !objects.isEmpty {
            children(objects)
        } else {
            Text("The referenced objects are no longer available. That's not good!")
        }
    }

}
