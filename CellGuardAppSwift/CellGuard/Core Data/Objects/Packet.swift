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
}

extension Packet {
    var proto: String {
        if (self is PacketARI) {
            return CPTProtocol.ari.rawValue
        } else if (self is PacketQMI) {
            return CPTProtocol.qmi.rawValue
        } else {
            return "UNK"
        }
    }
}

struct PacketContainer: Identifiable {
    
    let packet: any Packet
    
    var id: ObjectIdentifier {
        return packet.id
    }
}
