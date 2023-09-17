//
//  PersistenceCSVExporter.swift
//  CellGuard
//
//  Created by Lukas Arnold on 14.09.23.
//

import CoreData
import CSV
import Foundation
import UIKit
import OSLog
import ZIPFoundation

enum PersistenceCSVExporterError: Error {
    case noOutputStream
}

struct PersistenceCSVExporter {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: PersistenceCSVExporter.self)
    )
    
    static func exportInBackground(
        categories: [PersistenceCategory],
        progress: @escaping (Int, Int) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        
        var progressCounter = 0
        let progressMax = 5
        let localProgress = { () in
            progressCounter += 1
            DispatchQueue.main.async {
                progress(progressCounter, progressMax)
            }
        }
        
        DispatchQueue.main.async {
            progress(0, progressMax)
        }
        
        // Run the export in the background
        // See: https://www.hackingwithswift.com/read/9/4/back-to-the-main-thread-dispatchqueuemain
        DispatchQueue.global(qos: .userInitiated).async {
            let exporter = PersistenceCSVExporter(categories: categories)
            
            exporter.export(progress: localProgress, completion: { result in
                // Call the callback on the main queue
                DispatchQueue.main.async {
                    completion(result)
                }
            })
        }
    }
    
    let categories: [PersistenceCategory]
    let persistence: PersistenceController
    let numberFormatter: NumberFormatter
    
    private init(categories: [PersistenceCategory]) {
        self.categories = categories
        self.persistence = PersistenceController.basedOnEnvironment()
        
        // TODO: Is the precision correct?
        self.numberFormatter = NumberFormatter()
        numberFormatter.usesSignificantDigits = false
    }
    
    private func export(progress: @escaping () -> Void, completion: @escaping (Result<URL, Error>) -> Void) {
        completion(Result {
            do {
                // Current date for directory and file URLs
                // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/DataFormatting/Articles/dfDateFormatting10_4.html
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let dateString = dateFormatter.string(for: Date())!
                
                // Documents directory for the final file
                // https://www.hackingwithswift.com/books/ios-swiftui/writing-data-to-the-documents-directory
                let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                let documents = paths[0]
                
                // Path to the final archive
                let archiveURL = documents.appendingPathComponent("export-\(dateString).cells2")
                
                // Path to the temporary directory
                // https://nshipster.com/temporary-files/#creating-a-temporary-directory
                let directoryURL = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: archiveURL, create: true)
                
                Self.logger.debug("Writing data into files")
                try writeAll(categories: categories, directoryURL: directoryURL, progress: progress)
                
                Self.logger.debug("Compressing files into an archive")
                try compress(directoryURL: directoryURL, archiveUrl: archiveURL)
                progress()
                
                Self.logger.debug("Cleaning temporary directory")
                try clean(tmpDirectory: directoryURL)
                
                Self.logger.debug("Finished export: \(archiveURL)")
                return archiveURL
            } catch {
                Self.logger.warning("Failed to perform export: \(error)")
                throw error
            }
        })
    }
    
    private func writeAll(categories: [PersistenceCategory], directoryURL: URL, progress: () -> Void) throws {
        var dataFiles: [String: Int] = [:]
        
        for category in categories.filter({ $0 != .info }) {
            let count = try write(category: category, url: category.url(directory: directoryURL))
            dataFiles[category.fileName()] = count
            progress()
        }
        
        try writeInfo(url: PersistenceCategory.info.url(directory: directoryURL), data: dataFiles)
    }
    
    private func write(category: PersistenceCategory, url: URL) throws -> Int {
        Self.logger.debug("Writing \(String(describing: category)) to \(url)")
        
        switch (category) {
        case .info: return 0
        case .connectedCells: return try writeUserCells(url: url)
        case .alsCells: return try writeAlsCells(url: url)
        case .locations: return try writeLocations(url: url)
        case .packets: return try writePackets(url: url)
        }
    }
    
    private func writeInfo(url: URL, data: [String: Int]) throws {
        // https://developer.apple.com/documentation/uikit/uidevice?language=objc
        let device = UIDevice.current
        
        // https://stackoverflow.com/a/28153897
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "???"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String  ?? "???"
        
        let info: [String: Any] = [
            "name": device.name,
            "systemName": device.systemName,
            "systemVersion": device.systemVersion,
            "model": device.model,
            "localizedModel": device.localizedModel,
            "userInterfaceIdiom": String(device.userInterfaceIdiom.rawValue),
            "identifierForVendor": device.identifierForVendor?.uuidString ?? "nil",
            "cellguardVersion": "\(version) (\(build))",
            "data": data
        ]
        
        let json = try JSONSerialization.data(withJSONObject: info)
        try json.write(to: url)
    }
    
    private func openCSVWriter(url: URL) throws -> CSVWriter {
        guard let stream = OutputStream(url: url, append: false) else {
            throw PersistenceCSVExporterError.noOutputStream
        }
        
        return try CSVWriter(stream: stream)
    }
    
    private func writeUserCells(url: URL) throws -> Int {
        let csv = try openCSVWriter(url: url)
        defer { csv.stream.close() }
        
        try csv.write(row: ["collected", "json", "status", "score"])
        
        return try persistence.performAndWait { context in
            let request: NSFetchRequest<TweakCell> = TweakCell.fetchRequest()
            // Limit the number of entries concurrently loaded into memory
            // See: https://stackoverflow.com/a/52118107
            // See: https://developer.apple.com/documentation/coredata/nsfetchrequest/1506558-fetchbatchsize?language=objc
            request.fetchBatchSize = 100
            
            let results = try request.execute()
            for result in results {
                try csv.write(row: [
                    csvDate(result.collected),
                    csvString(result.json),
                    csvString(result.status),
                    csvNumber(result.score)
                ])
            }
            
            return results.count
        } ?? 0
    }
    
    private func writeAlsCells(url: URL) throws -> Int {
        let csv = try openCSVWriter(url: url)
        defer { csv.stream.close() }
        
        try csv.write(row: ["imported", "technology", "country", "network", "area", "cell", "frequency", "physicalCell", "latitude", "longitude", "horizontalAccuracy", "reach", "score"])
        
        return try persistence.performAndWait { context in
            let request: NSFetchRequest<ALSCell> = ALSCell.fetchRequest()
            request.fetchBatchSize = 100
            request.relationshipKeyPathsForPrefetching = ["location"]
            
            let results = try request.execute()
            for result in results {
                let location = result.location
                try csv.write(row: [
                    csvDate(result.imported),
                    csvString(result.technology),
                    csvNumber(result.country),
                    csvNumber(result.network),
                    csvNumber(result.area),
                    csvNumber(result.cell),
                    csvNumber(result.frequency),
                    csvNumber(result.physicalCell),
                    csvNumber(location?.latitude),
                    csvNumber(location?.longitude),
                    csvNumber(location?.horizontalAccuracy),
                    csvNumber(location?.reach),
                    csvNumber(location?.score),
                ])
            }
            
            return results.count
        } ?? 0
    }
    
    private func writeLocations(url: URL) throws -> Int {
        let csv = try openCSVWriter(url: url)
        defer { csv.stream.close() }
        
        try csv.write(row: ["collected", "latitude", "longitude", "horizontalAccuracy", "altitude", "verticalAccuracy", "speed", "speedAccuracy", "background"])
        
        return try persistence.performAndWait { context in
            let request: NSFetchRequest<UserLocation> = UserLocation.fetchRequest()
            request.fetchBatchSize = 100
            
            let results = try request.execute()
            for result in results {
                try csv.write(row: [
                    csvDate(result.collected),
                    csvNumber(result.latitude),
                    csvNumber(result.longitude),
                    csvNumber(result.horizontalAccuracy),
                    csvNumber(result.altitude),
                    csvNumber(result.verticalAccuracy),
                    csvNumber(result.speed),
                    csvNumber(result.speedAccuracy),
                    csvBool(result.background)
                ])
            }
            
            return results.count
        } ?? 0
    }
    
    private func writePackets(url: URL) throws -> Int {
        let csv = try openCSVWriter(url: url)
        defer { csv.stream.close() }
        
        try csv.write(row: ["collected", "direction", "proto", "data"])
        
        return try persistence.performAndWait { context in
            let request: NSFetchRequest<Packet> = Packet.fetchRequest()
            request.fetchBatchSize = 100
            
            let results = try request.execute()
            for result in results {
                try csv.write(row: [
                    csvDate(result.collected),
                    csvString(result.direction),
                    csvString(result.proto),
                    csvString(result.data?.base64EncodedString())
                ])
            }
            
            return results.count
        } ?? 0
    }
    
    private func csvString(_ string: String?) -> String {
        return string ?? "nil"
    }
    
    private func csvBool(_ bool: Bool) -> String {
        return bool.description
    }
    
    private func csvDate(_ date: Date?) -> String {
        return csvNumber(date?.timeIntervalSince1970)
    }
    
    private func csvNumber(_ value: (any BinaryInteger)?) -> String {
        if let value = value {
            return String(value)
        } else {
            return "nil"
        }
    }
    
    private func csvNumber(_ value: Double?) -> String {
        if let value = value {
            return String(value)
        } else {
            return "nil"
        }
    }
    
    private func compress(directoryURL: URL, archiveUrl: URL) throws {
        // Options for creating archives:
        // - Apple Archive: https://developer.apple.com/documentation/applearchive?language=objc
        // - ZIPFoundation: https://github.com/weichsel/ZIPFoundation
        
        // https://github.com/weichsel/ZIPFoundation#zipping-files-and-directories
        try FileManager.default.zipItem(at: directoryURL, to: archiveUrl, shouldKeepParent: false, compressionMethod: .deflate)
    }
    
    private func clean(tmpDirectory: URL) throws {
        // Deleting the source directory
        try FileManager.default.removeItem(at: tmpDirectory)
    }
    
}
