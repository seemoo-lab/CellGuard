//
//  NavObjectId.swift
//  CellGuard
//
//  Created by Lukas Arnold on 20.06.25.
//

import Foundation
import CoreData
import SwiftUI

struct NavObjectId<T: NSManagedObject>: Hashable {

    let id: NSManagedObjectID

    init(id: NSManagedObjectID) {
        self.id = id
    }

    init(object: T) {
        self.id = object.objectID
    }

    var object: T? {
        // The object might got removed while the new view was built
        PersistenceController.shared.container.viewContext.object(with: id) as? T
    }

    @ViewBuilder
    func ensure<Children: View>(@ViewBuilder children: (_ object: T) -> Children) -> some View {
        if let object = object {
            children(object)
        } else {
            Text("The referenced object is no longer available. That's not good!")
        }
    }

}
