//
//  VerificationRelatedObjectId.swift
//  CellGuard
//
//  Created by Lukas Arnold on 28.08.25.
//

import Foundation
import CoreData
import SwiftUI

struct VerificationRelatedObjectId<T: NSManagedObject>: Hashable {

    let id: NSManagedObjectID

    init(id: NSManagedObjectID) {
        self.id = id
    }

    init(object: T) {
        self.id = object.objectID
    }

    var object: T? {
        // The object might got removed while the new view was built
        PersistenceController.basedOnEnvironment().container.viewContext.object(with: id) as? T
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

struct VerificationRelatedDistance: Hashable {
    let cellAlsId: NSManagedObjectID
    let userLocationId: NSManagedObjectID

    init(cellAls: CellALS, userLocation: LocationUser) {
        self.cellAlsId = cellAls.objectID
        self.userLocationId = userLocation.objectID
    }

    @ViewBuilder
    func ensure<Children: View>(@ViewBuilder children: (_ cell: CellALS, _ loc: LocationUser) -> Children) -> some View {
        let viewContext =  PersistenceController.basedOnEnvironment().container.viewContext
        if let cellAls = viewContext.object(with: cellAlsId) as? CellALS,
           let userLocation = viewContext.object(with: userLocationId) as? LocationUser {
            children(cellAls, userLocation)
        } else {
            Text("The referenced object is no longer available. That's not good!")
        }
    }
}

struct VerificationRelatedPackets: Hashable {

    let packetIds: [NSManagedObjectID]

    init(packets: [any Packet]) {
        self.packetIds = packets.map { $0.objectID }
    }

    var packets: [any Packet] {
        let viewContext = PersistenceController.basedOnEnvironment().container.viewContext
        return packetIds.compactMap { id in
            viewContext.object(with: id) as? any Packet
        }
    }

    @ViewBuilder
    func ensure<Children: View>(@ViewBuilder children: (_ object: [any Packet]) -> Children) -> some View {
        let packets = packets
        if !packets.isEmpty {
            children(packets)
        } else {
            Text("The referenced object is no longer available. That's not good!")
        }
    }
}
