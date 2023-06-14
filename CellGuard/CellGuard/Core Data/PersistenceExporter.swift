//
//  PersistenceExporter.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.01.23.
//

import CoreData
import Foundation
import OSLog
import UIKit

enum PersistenceExportError: Error {
    case noResultSet
    case fetchOrSerializationFailed(Error)
}

struct PersistenceExporter {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: PersistenceExporter.self)
    )
    
    static func exportInBackground(categories: [PersistenceCategory], completion: @escaping (Result<URL, Error>) -> Void) {
        // See: https://www.hackingwithswift.com/read/9/4/back-to-the-main-thread-dispatchqueuemain
        
        // Run the export in the background
        DispatchQueue.global(qos: .userInitiated).async {
            let exporter = PersistenceExporter(categories: categories)
            
            exporter.export { result in
                // Call the callback on the main queue
                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }
    }
    
    let categories: [PersistenceCategory]
    
    private init(categories: [PersistenceCategory]) {
        self.categories = categories
    }
    
    private func export(completion: @escaping (Result<URL, Error>) -> Void) {
        let url = exportURL()
        
        let data: Data
        do {
            data = try fetchData()
        } catch {
            Self.logger.warning("Can't fetch data: \(error)")
            completion(.failure(error))
            return
        }
        
        do {
            try data.write(to: url)
        } catch {
            Self.logger.warning("Can't write data to \(url): \(error)")
            completion(.failure(error))
            return
        }
        
        Self.logger.debug("Exported data to file \(url)")
        
        return completion(.success(url))
    }
    
    private func fetchData() throws -> Data {
        let context = PersistenceController.shared.newTaskContext()
        
        var result: Data? = nil
        var processingError: Error? = nil
        
        context.performAndWait {
            do {
                var connectedCells: [TweakCell] = []
                var alsCells: [ALSCell] = []
                var locations: [UserLocation] = []
                var packets: [Packet] = []
                
                if (categories.contains(.connectedCells)) {
                    let fetchConnectedCells = NSFetchRequest<TweakCell>()
                    fetchConnectedCells.entity = TweakCell.entity()
                    
                    connectedCells.append(contentsOf: try fetchConnectedCells.execute())
                    Self.logger.debug("Exporting \(connectedCells.count) cells the iPhone connected to")
                }
                if (categories.contains(.alsCells)) {
                    let fetchALSCells = NSFetchRequest<ALSCell>()
                    fetchALSCells.entity = ALSCell.entity()
                    fetchALSCells.relationshipKeyPathsForPrefetching = ["location"]
                    
                    alsCells.append(contentsOf: try fetchALSCells.execute())
                    Self.logger.debug("Exporting \(alsCells.count) ALS cells")
                }
                if (categories.contains(.locations)) {
                    let fetchLocations = NSFetchRequest<UserLocation>()
                    fetchLocations.entity = UserLocation.entity()
                    
                    locations.append(contentsOf: try fetchLocations.execute())
                    Self.logger.debug("Exporting \(locations.count) user locations")
                }
                if (categories.contains(.packets)) {
                    let fetchQMIPackets = NSFetchRequest<QMIPacket>()
                    fetchQMIPackets.entity = QMIPacket.entity()
                    let fetchARIPackets = NSFetchRequest<ARIPacket>()
                    fetchARIPackets.entity = ARIPacket.entity()
                    
                    packets.append(contentsOf: try fetchQMIPackets.execute())
                    packets.append(contentsOf: try fetchARIPackets.execute())
                    Self.logger.debug("Exporting \(packets.count) packets")
                }
                
                // Sometimes the app just crashes here
                result = try toJSON(connectedCells: connectedCells, alsCells: alsCells, userLocations: locations, packets: packets)
            } catch {
                Self.logger.warning("Can't fetch data or serialize it: \(error)")
                processingError = error
            }
            
        }
        
        if let error = processingError {
            throw PersistenceExportError.fetchOrSerializationFailed(error)
        }
        
        guard let result = result else {
            throw PersistenceExportError.noResultSet
        }
        
        return result
    }
    
    private func toJSON(connectedCells: [TweakCell], alsCells: [ALSCell], userLocations: [UserLocation], packets: [Packet]) throws -> Data {
        var dict: [String: Any] = [:]
        
        if categories.contains(.connectedCells) {
            // TODO: Think about cells without JSON data
            // TODO: Print error for failures
            dict[CellFileKeys.connectedCells] = connectedCells
                .compactMap { $0.json?.data(using: .utf8) }
                .compactMap { try? JSONSerialization.jsonObject(with: $0) }
        }
        
        if categories.contains(.alsCells) {
            dict[CellFileKeys.alsCells] = alsCells
                .map { exportALSCell(alsCell: $0) }
        }
        
        if categories.contains(.locations) {
            dict[CellFileKeys.locations] = userLocations
                .map { TrackedUserLocation(from: $0) }
                .map { $0.toDictionary() }
        }
        
        if categories.contains(.packets) {
            dict[CellFileKeys.packets] = packets
                .map { exportPacket(packet: $0) }
        }
        
        // https://developer.apple.com/documentation/uikit/uidevice?language=objc
        let device = UIDevice.current
        dict[CellFileKeys.device] = [
            "name": device.name,
            "systemName": device.systemName,
            "systemVersion": device.systemVersion,
            "model": device.model,
            "localizedModel": device.localizedModel,
            "userInterfaceIdiom": String(device.userInterfaceIdiom.rawValue),
            "identifierForVendor": device.identifierForVendor?.uuidString ?? "nil"
        ] as [String : String]
        
        dict[CellFileKeys.date] = Date().timeIntervalSince1970
        
        return try JSONSerialization.data(withJSONObject: dict)
    }
    
    private func exportALSCell(alsCell cell: ALSCell) -> [String: Any] {
        var cellDict: [String: Any] = [
            ALSCellDictKeys.technology: cell.technology ?? "",
            ALSCellDictKeys.country: cell.country,
            ALSCellDictKeys.network: cell.network ,
            ALSCellDictKeys.cell: cell.cell,
            ALSCellDictKeys.frequency: cell.frequency,
            ALSCellDictKeys.imported: cell.imported?.timeIntervalSince1970 ?? 0,
        ]
        
        if let location = cell.location {
            cellDict[ALSCellDictKeys.location] = [
                ALSLocationDictKeys.horizontalAccuracy: location.horizontalAccuracy,
                ALSLocationDictKeys.latitude: location.latitude,
                ALSLocationDictKeys.longitude: location.longitude,
                ALSLocationDictKeys.imported: location.imported?.timeIntervalSince1970 ?? 0,
                ALSLocationDictKeys.reach: location.reach,
                ALSLocationDictKeys.score: location.score,
            ] as [String : Any]
        }
        
        return cellDict
    }
    
    private func exportPacket(packet: Packet) -> [String: Any] {
        return [
            PacketDictKeys.direction: packet.direction ?? "",
            PacketDictKeys.proto: packet.proto ?? "",
            PacketDictKeys.collected: packet.collected?.timeIntervalSince1970 ?? 0,
            PacketDictKeys.data: packet.data?.base64EncodedString() ?? ""
        ]
    }
    
    private func exportURL() -> URL {
        // https://www.hackingwithswift.com/books/ios-swiftui/writing-data-to-the-documents-directory
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documents = paths[0]
        
        // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/DataFormatting/Articles/dfDateFormatting10_4.html
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(for: Date())!
        
        return documents.appendingPathComponent("export-\(dateString).cells")
    }
    
}
