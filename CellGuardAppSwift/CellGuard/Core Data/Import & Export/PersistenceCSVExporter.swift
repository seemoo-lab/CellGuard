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
    case noCSVDataInMemory
}

typealias CSVProgressFunc = (PersistenceCategory, Int, Int) -> Void

// We had to encapsulate all functions to this protocol, otherwise the compiler doesn't allow array of different generic types.
protocol FileElementWriter {
    func count(context: NSManagedObjectContext) throws -> Int
    func write(fileHandle: FileHandle, csv: inout CSVWriter, counter: inout Int, count: Int, progress: CSVProgressFunc, category: PersistenceCategory) throws -> Void
}

struct DatabaseFileElementWriter<T: NSFetchRequestResult>: FileElementWriter {
    private let fetchRequest: NSFetchRequest<T>
    private let writeElement: (CSVWriter, T) throws -> Void
    
    init(_ fetchRequest: () -> NSFetchRequest<T>, _ writeElement: @escaping (CSVWriter, T) throws -> Void) {
        self.fetchRequest = fetchRequest()
        self.writeElement = writeElement
    }
    
    func count(context: NSManagedObjectContext) throws -> Int {
        return try context.count(for: fetchRequest)
    }
    
    func write(fileHandle: FileHandle, csv: inout CSVWriter, counter: inout Int, count: Int, progress: CSVProgressFunc, category: PersistenceCategory) throws {
        // Init the fetch request object
        // Limit the number of entries concurrently loaded into memory
        // See: https://stackoverflow.com/a/52118107
        // See: https://developer.apple.com/documentation/coredata/nsfetchrequest/1506558-fetchbatchsize?language=objc
        fetchRequest.fetchBatchSize = 1000
        
        // Execute the request and process its entries
        for result in try fetchRequest.execute() {
            // Use an autorelease pool to reduce the memory impact when exporting (very important)
            // See: https://swiftrocks.com/autoreleasepool-in-swift
            // See: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MemoryMgmt/Articles/mmAutoreleasePools.html
            try autoreleasepool {
                // Write the data point to the CSV file
                try writeElement(csv, result)
                
                // Send counter updates only once every 1000 data points
                counter += 1
                if counter % 1000 == 0 {
                    // Get the CSV data from memory
                    csv.stream.close()
                    guard let data = csv.stream.property(forKey: .dataWrittenToMemoryStreamKey) as? Data else {
                        throw PersistenceCSVExporterError.noCSVDataInMemory
                    }
                    
                    // Write data to the file
                    try fileHandle.write(contentsOf: data)
                    
                    // Append a new line as the string produced by the library doesn't end with one
                    try fileHandle.write(contentsOf: "\n".data(using: .utf8)!)

                    // Create a new CSV writer
                    csv = try CSVWriter(stream: .toMemory())
                    
                    progress(category, counter, count)
                }
            }
        }
    }
}

struct PersistenceCSVExporter {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: PersistenceCSVExporter.self)
    )
    
    static func exportInBackground(
        categories: [PersistenceCategory],
        progress: @escaping CSVProgressFunc,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        PortStatus.exportActive.store(true, ordering: .relaxed)
        
        let localProgress = { (category, current, total) in
            DispatchQueue.main.async {
                progress(category, current, total)
            }
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
                PortStatus.exportActive.store(false, ordering: .relaxed)
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
    
    private func export(progress: @escaping CSVProgressFunc, completion: @escaping (Result<URL, Error>) -> Void) {
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
                // progress()
                
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
    
    private func writeAll(categories: [PersistenceCategory], directoryURL: URL, progress: CSVProgressFunc) throws {
        var dataFiles: [String: Int] = [:]
        
        for category in categories.sorted().filter({ $0 != .info }) {
            let count = try write(category: category, url: category.url(directory: directoryURL), progress: progress)
            dataFiles[category.fileName()] = count
        }
        
        try writeInfo(url: PersistenceCategory.info.url(directory: directoryURL), data: dataFiles, progress: progress)
    }
    
    private func write(category: PersistenceCategory, url: URL, progress: CSVProgressFunc) throws -> Int {
        Self.logger.debug("Writing \(String(describing: category)) to \(url)")
        
        switch (category) {
        case .info: return 0
        case .connectedCells: return try writeUserCells(url: url, progress: progress)
        case .alsCells: return try writeAlsCells(url: url, progress: progress)
        case .locations: return try writeLocations(url: url, progress: progress)
        case .packets: return try writePackets(url: url, progress: progress)
        }
    }
    
    private func writeInfo(url: URL, data: [String: Int], progress: CSVProgressFunc) throws {
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
    
    private func writeData(
        url: URL,
        category: PersistenceCategory,
        progress: CSVProgressFunc,
        header: [String],
        writers: [FileElementWriter]
    ) throws -> Int {
        // Create the CSV file and its file handle
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: url)
        defer { try? fileHandle.close() }
        
        // Request the data from the DB and write it sequentially to the file
        return try persistence.performAndWait { context in
            // General advice for reducing the memory footprint of Core Data
            // See: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/Performance.html#//apple_ref/doc/uid/TP40001075-CH25-SW10
            context.undoManager = nil
            
            // Don't keep strong references to all objects loaded in this context as we just have to read them once
            // See: https://developer.apple.com/documentation/coredata/nsmanagedobjectcontext/1506290-retainsregisteredobjects
            context.retainsRegisteredObjects = false
            
            // Count the number of data points in the table & update the process
            let count = try writers.map { try $0.count(context: context) }.reduce(0, +)
            var counter = 0
            progress(category, counter, count)
            
            // It's faster to write 1000 objects to memory and then to write them in bulk to disk
            // See: https://github.com/yaslab/CSV.swift#write-to-memory-and-get-a-csv-string
            var csv = try CSVWriter(stream: .toMemory())
            
            // Write the header row
            try csv.write(row: header)
            
            for writer in writers {
                try writer.write(fileHandle: fileHandle, csv: &csv, counter: &counter, count: count, progress: progress, category: category)
            }
            
            // Get the final CSV data from memory
            csv.stream.close()
            guard let data = csv.stream.property(forKey: .dataWrittenToMemoryStreamKey) as? Data else {
                throw PersistenceCSVExporterError.noCSVDataInMemory
            }
            
            // Write data to the file
            try fileHandle.write(contentsOf: data)
            
            // Append a new line as the string produced by the library doesn't end with one
            try fileHandle.write(contentsOf: "\n".data(using: .utf8)!)
            
            progress(category, counter, count)
            
            return count
        } ?? 0
    }
    
    private func writeUserCells(url: URL, progress: CSVProgressFunc) throws -> Int {
        return try writeData(
            url: url,
            category: .connectedCells,
            progress: progress,
            header: ["collected", "json", "technology", "country", "network", "area", "cell", "verificationFinished", "verificationScore"],
            writers: [DatabaseFileElementWriter(CellTweak.fetchRequest) { csv, result in
                try csv.write(row: [
                    csvDate(result.collected),
                    csvString(result.json),
                    csvString(result.technology),
                    csvInt(result.country),
                    csvInt(result.network),
                    csvInt(result.area),
                    csvInt(result.cell),
                    csvBool(result.primaryVerification?.finished ?? false),
                    csvInt(result.primaryVerification?.score ?? 0),
                ])
            }]
        )
    }
    
    private func writeAlsCells(url: URL, progress: CSVProgressFunc) throws -> Int {
        return try writeData(
            url: url,
            category: .alsCells,
            progress: progress,
            header: ["imported", "technology", "country", "network", "area", "cell", "frequency", "physicalCell", "latitude", "longitude", "horizontalAccuracy", "reach", "score"],
            writers: [DatabaseFileElementWriter({
                let request: NSFetchRequest<CellALS> = CellALS.fetchRequest()
                request.relationshipKeyPathsForPrefetching = ["location"]
                return request
            }) { csv, result in
                let location = result.location
                
                try csv.write(row: [
                    csvDate(result.imported),
                    csvString(result.technology),
                    csvInt(result.country),
                    csvInt(result.network),
                    csvInt(result.area),
                    csvInt(result.cell),
                    csvInt(result.frequency),
                    csvInt(result.physicalCell),
                    csvDouble(location?.latitude),
                    csvDouble(location?.longitude),
                    csvDouble(location?.horizontalAccuracy),
                    csvInt(location?.reach),
                    csvInt(location?.score),
                ])
            }]
        )
    }
    
    private func writeLocations(url: URL, progress: CSVProgressFunc) throws -> Int {
        return try writeData(
            url: url,
            category: .locations,
            progress: progress,
            header: ["collected", "latitude", "longitude", "horizontalAccuracy", "altitude", "verticalAccuracy", "speed", "speedAccuracy", "background"],
            writers: [DatabaseFileElementWriter(LocationUser.fetchRequest) { csv, result in
                try csv.write(row: [
                    csvDate(result.collected),
                    csvDouble(result.latitude),
                    csvDouble(result.longitude),
                    csvDouble(result.horizontalAccuracy),
                    csvDouble(result.altitude),
                    csvDouble(result.verticalAccuracy),
                    csvDouble(result.speed),
                    csvDouble(result.speedAccuracy),
                    csvBool(result.background)
                ])
            }]
        )
    }
    
    private func writePackets(url: URL, progress: CSVProgressFunc) throws -> Int {
        return try writeData(
            url: url,
            category: .packets,
            progress: progress,
            header: ["collected", "direction", "proto", "data"],
            writers: [
                DatabaseFileElementWriter(PacketQMI.fetchRequest) { csv, result in
                    try csv.write(row: [
                        csvDate(result.collected),
                        csvString(result.direction),
                        csvString(result.proto),
                        csvString(result.data?.base64EncodedString())
                    ])
                },
                DatabaseFileElementWriter(PacketARI.fetchRequest) { csv, result in
                    try csv.write(row: [
                        csvDate(result.collected),
                        csvString(result.direction),
                        csvString(result.proto),
                        csvString(result.data?.base64EncodedString())
                    ])
                }
            ]
        )
    }
    
    private func csvString(_ string: String?) -> String {
        return string ?? "nil"
    }
    
    private func csvBool(_ bool: Bool) -> String {
        return bool.description
    }
    
    private func csvDate(_ date: Date?) -> String {
        return csvDouble(date?.timeIntervalSince1970)
    }
    
    private func csvInt(_ value: (any BinaryInteger)?) -> String {
        if let value = value {
            return String(value)
        } else {
            return "nil"
        }
    }
    
    private func csvDouble(_ value: Double?) -> String {
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
