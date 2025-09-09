//
//  Packet.swift
//  CellGuard
//
//  Created by Lukas Arnold on 11.04.24.
//

import Foundation
import CoreData

public protocol Packet: NSFetchRequestResult, Identifiable {
    var collected: Date? { get set }
    var data: Data? { get set }
    var direction: String? { get set }
    var imported: Date? { get set }
    var simSlotID: Int16 { get set }
    var objectID: NSManagedObjectID { get }
}

extension Packet {
    var proto: String {
        if self is PacketARI {
            return CPTProtocol.ari.rawValue
        } else if self is PacketQMI {
            return CPTProtocol.qmi.rawValue
        } else {
            return "UNK"
        }
    }
}

struct PacketContainer: Identifiable, Hashable {

    let packet: any Packet

    var id: ObjectIdentifier {
        return packet.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(packet.hash)
    }

    static func == (lhs: PacketContainer, rhs: PacketContainer) -> Bool {
        lhs.id == rhs.id
    }
}
