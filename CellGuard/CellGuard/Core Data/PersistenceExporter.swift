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
    case fetchOrSerilizationFailed(Error)
}

struct PersistenceExporter {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: PersistenceExporter.self)
    )
    
    static func exportInBackground(completion: @escaping (Result<URL, Error>) -> Void) {
        // See: https://www.hackingwithswift.com/read/9/4/back-to-the-main-thread-dispatchqueuemain
        
        // Run the export in the background
        DispatchQueue.global(qos: .userInitiated).async {
            let exporter = PersistenceExporter()
            
            exporter.export { result in
                // Call the callback on the main queue
                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }
    }
    
    private init() {
        
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

        return completion(.success(url))
    }
    
    private func fetchData() throws -> Data {
        let context = PersistenceController.shared.newTaskContext()
        
        var result: Data? = nil
        var processingError: Error? = nil
        
        context.performAndWait {
            let fetchCells = NSFetchRequest<TweakCell>()
            fetchCells.entity = TweakCell.entity()
            
            let fetchLocations = NSFetchRequest<UserLocation>()
            fetchLocations.entity = UserLocation.entity()
            
            do {
                let cells = try fetchCells.execute()
                let locations = try fetchLocations.execute()
                
                Self.logger.debug("Exporting \(cells.count) cells and \(locations.count) locations")
                
                // TODO: Why does the app crash and just doesn't report the error?
                result = try toJSON(tweakCells: cells, userLocations: locations)
            } catch {
                Self.logger.warning("Can't fetch data or serialize it: \(error)")
                processingError = error
            }
            
        }
        
        if let error = processingError {
            throw PersistenceExportError.fetchOrSerilizationFailed(error)
        }
        
        guard let result = result else {
            throw PersistenceExportError.noResultSet
        }
        
        return result
    }
    
    private func toJSON(tweakCells: [TweakCell], userLocations: [UserLocation]) throws -> Data {
        var dict: [String: Any] = [:]
        
        // TODO: Think about cells without JSON data
        dict["cells"] = tweakCells
            .compactMap { $0.json?.data(using: .utf8) }
            // TODO: Print error for failures
            .compactMap { try? JSONSerialization.jsonObject(with: $0) }
        
        // https://stackoverflow.com/a/50270620
        dict["locations"] = userLocations
            .map { location in [
                "latitude": location.latitude,
                "longitude": location.longitude,
                "horizontalAccuracy": location.horizontalAccuracy,
                "altitude": location.altitude,
                "verticalAccuracy": location.verticalAccuracy,
                "collected": location.collected?.timeIntervalSince1970 ?? 0,
            ] }
        
        // https://developer.apple.com/documentation/uikit/uidevice?language=objc
        let device = UIDevice.current
        dict["device"] = [
            "name": device.name,
            "systemName": device.systemName,
            "systemVersion": device.systemVersion,
            "model": device.model,
            "localizedModel": device.localizedModel,
            "userInterfaceIdiom": device.userInterfaceIdiom.rawValue,
            "identifierForVendor": device.identifierForVendor?.uuidString ?? "nil"
        ]
        
        dict["date"] = Date().timeIntervalSince1970
        
        return try JSONSerialization.data(withJSONObject: dict)
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
