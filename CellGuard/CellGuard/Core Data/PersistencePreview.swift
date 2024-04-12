//
//  PersistencePreview.swift
//  CellGuard
//
//  Created by Lukas Arnold on 08.01.23.
//

import Foundation
import CoreData

struct PersistencePreview {
    
    static func userLocation(location: LocationUser, error: Double) -> LocationUser {
        location.latitude = 49.8726737 + Double.random(in: -error..<error)
        location.longitude = 8.6516291 + Double.random(in: -error..<error)
        location.horizontalAccuracy = 2 + Double.random(in: -0.5..<0.5)

        return location
    }
    
    static func alsLocation(location: LocationALS, error: Double) -> LocationALS {
        location.latitude = 49.8726737 + Double.random(in: -error..<error)
        location.longitude = 8.6516291 + Double.random(in: -error..<error)
        location.horizontalAccuracy = 2 + Double.random(in: -0.5..<0.5)

        return location
    }
    
    static func tweakCell(context: NSManagedObjectContext, imported: Date) -> CellTweak {
        let cell = CellTweak(context: context)
        cell.technology = "LTE"
        cell.country = 262
        cell.network = 2
        cell.area = Int32.random(in: 1..<5000)
        cell.cell = Int64.random(in: 1..<50000)
        cell.collected = Calendar.current.date(byAdding: .day, value: -Int.random(in: 0..<3), to: Date())
        cell.imported = imported
        cell.location = userLocation(location: LocationUser(context: context), error: 0.005)
        cell.location?.imported = cell.imported
        cell.status = CellStatus.verified.rawValue
        cell.score = Int16(CellVerifier.pointsMax)
        cell.nextVerification = Date()
        
        return cell
    }
    
    static func tweakCell(context: NSManagedObjectContext, from alsCell: CellALS) -> CellTweak {
        let cell = CellTweak(context: context)
        cell.technology = alsCell.technology
        cell.country = alsCell.country
        cell.network = alsCell.network
        cell.area = alsCell.area
        cell.cell = alsCell.cell
        cell.collected = Calendar.current.date(byAdding: .day, value: -Int.random(in: 0..<3), to: Date())
        cell.imported = Calendar.current.date(byAdding: .hour, value: -Int.random(in: 0..<24), to: alsCell.imported!)
        cell.location = userLocation(location: LocationUser(context: context), error: 0.01)
        cell.location?.imported = cell.imported
        cell.status = CellStatus.imported.rawValue
        cell.score = 0
        cell.nextVerification = Date()
        
        return cell

    }
    
    static func alsCell(context: NSManagedObjectContext) -> CellALS {
        let cell = CellALS(context: context)
        cell.technology = "LTE"
        cell.country = 262
        cell.network = Int32.random(in: 0..<5)
        cell.area = Int32.random(in: 1..<5000)
        cell.cell = Int64.random(in: 1..<50000)
        cell.imported = Calendar.current.date(byAdding: .day, value: -Int.random(in: 0..<3), to: Date())
        cell.location = alsLocation(location: LocationALS(context: context), error: 0.005)
        cell.location?.imported = cell.imported
        
        for _ in 0...Int.random(in: 2..<7) {
            _ = PersistencePreview.tweakCell(context: context, from: cell)
        }

        return cell
    }
    
    static func packet(proto: CPTProtocol, direction: CPTDirection, data: String, major: UInt8, minor: UInt16, indication: Bool, collected: Date, context: NSManagedObjectContext) -> any Packet {
        var packet: any Packet
        
        switch (proto) {
        case .qmi:
            let qmiPacket = PacketQMI(context: context)
            qmiPacket.service = Int16(major)
            qmiPacket.message = Int32(minor)
            qmiPacket.indication = indication
            packet = qmiPacket
        case .ari:
            let ariPacket = PacketARI(context: context)
            ariPacket.group = Int16(major)
            ariPacket.type = Int32(minor)
            packet = ariPacket
        }
        
        packet.collected = collected
        packet.direction = direction.rawValue
        packet.data = Data(base64Encoded: data)
        packet.imported = Date()
        
        return packet
    }
    
    static func packets(context: NSManagedObjectContext) -> [any Packet] {
        var packets: [any Packet] = []
        
        // 4th packet from the test trace
        packets.append(packet(proto: .qmi, direction: .outgoing, data: "ARcAACIBAE8FUQALAAEBAAAQBAAHAAAA", major: 0x22, minor: 0x0051, indication: false, collected: Date().addingTimeInterval(-60*2), context: context))
        // 269th packet from the test trace
        packets.append(packet(proto: .qmi, direction: .ingoing, data: "ARcAgAAAASIiAAwAAgQAAAAAAAECADAM", major: 0x00, minor: 0x0022, indication: false, collected: Date().addingTimeInterval(-60*4), context: context))
        // 1702th packet from the test trace
       packets.append(packet(proto: .qmi, direction: .ingoing, data: "AbYAgAMBBBYATgCqABACAAAAEQIAAAASAwAAAAATAwAAAAAUAwACAgAZHQABAwEDAQABAAD//wEDF+8AAAAAATI2MjAy/wF0tR4CAP//IQEAAScBAAAoBAABAAAAKgEAASsEAAEAAAAwBAAAAAAAMgQAAAAAADUCAP//OQQAAQAAADoEAAEAAAA/BAAAAAAARQQAAwAAAEcEAAQAAABMAwAAAABQAQABUQEAAFcBAAFdBAAAAAAA", major: 0x03, minor: 0x004E, indication: true, collected: Date().addingTimeInterval(-60*60*24*2), context: context))
        
        // 1st packet from the test trace
        packets.append(packet(proto: .ari, direction: .ingoing, data: "3sB+q3igoABCwAAAAiAQAAAAAAAGIBAA8BMAAAggEAAAAAAACiCwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADCAQAAAAAAA=", major: 15, minor: 0x301, indication: false, collected: Date().addingTimeInterval(-60*3), context: context))
        // 19th packet from the test trace
        // We don't know if the packet was in- or outgoing but for our UI testing, we categorize it to outgoing
        packets.append(packet(proto: .ari, direction: .outgoing, data: "3sB+qxjENAHCwgAAAiAQAAAAAAAEIAQA8QYgBAAyCCAQABQAAAAKIFAAAAAAAAAAAAAAAAAAAAAAADIAAAAMIJAB8TIAAAAAAAAAAAAAAAAAAAAAMgAAAAMAAAA34gAA0cIAAETB8////5j///8AAAAAAAAAAAAAAAAAAAAAAAAAAAYAAAAAAAAAWOQbhRiAHIUQOvCEAAAAAABgsFEAAAAAkXDfhQ==", major: 3, minor: 0x030B, indication: false, collected: Date().addingTimeInterval(-60*60*24*1), context: context))

        return packets
    }
    
    static func controller() -> PersistenceController {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        let importedDate = Date()
        
        for _ in 0..<10 {
            // TODO: One cell at multiple dates
            _ = tweakCell(context: viewContext, imported: importedDate)
            _ = alsCell(context: viewContext)
        }
        
        _ = packets(context: viewContext)
        
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }
    
}
