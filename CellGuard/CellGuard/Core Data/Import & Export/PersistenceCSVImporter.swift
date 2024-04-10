//
//  PersistenceCSVImporter.swift
//  CellGuard
//
//  Created by Lukas Arnold on 25.09.23.
//

import CSV
import CoreData
import Foundation
import OSLog
import ZIPFoundation

enum PersistenceCSVImporterError: Error {
    case noInputStream
    case notInInfo
    case cantOpenArchive(Error)
    case infoMissing
    case infoWrongFormat
    case permissionDenied
    
    case fieldMissing(String)
    case fieldNil(String)
    case fieldParsing(String)
    case fieldJSONParsing(String)
    case fieldDoubleParsing(String)
    case fieldIntParsing(String)
}

struct PersistenceCSVImporter {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: PersistenceCSVImporter.self)
    )
    
    static func queryArchiveInfo(
        url: URL,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result.init {
                try PersistenceCSVImporter().fetchInfo(from: url)
            }
            DispatchQueue.main.async {
                completion(result)
            }
            PortStatus.importActive.store(false, ordering: .relaxed)
        }
    }
    
    static func importInBackground(
        url: URL,
        progress: @escaping CSVProgressFunc,
        completion: @escaping (Result<ImportResult, Error>) -> Void
    ) {
        PortStatus.importActive.store(true, ordering: .relaxed)
        
        let localProgress = { (category, current, total) in
            DispatchQueue.main.async {
                progress(category, current, total)
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result.init {
                try PersistenceCSVImporter().importAll(from: url, progress: localProgress)
            }
            DispatchQueue.main.async {
                completion(result)
            }
            PortStatus.importActive.store(false, ordering: .relaxed)
        }
    }
    
    private init() {
        
    }
    
    func importAll(from url: URL, progress: @escaping CSVProgressFunc) throws -> ImportResult {
        let fileManager = FileManager.default
        
        // This function call is required on iOS 16 to read files to be imported
        let securityScoped = url.startAccessingSecurityScopedResource()
        defer { if securityScoped { url.stopAccessingSecurityScopedResource() } }
        Self.logger.debug("Access to security scoped resources")
        
        // Create a temporary directory for extracting the file and remove it afterwards
        let tmpDirectoryURL = try fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: url, create: true)
        defer { try? FileManager.default.removeItem(at: tmpDirectoryURL) }
        Self.logger.debug("Creating temporary directory at \(tmpDirectoryURL)")
        
        // Extract the whole archive into the folder
        try fileManager.unzipItem(at: url, to: tmpDirectoryURL)
        Self.logger.debug("Unzipped to temporary directory")
        
        // Import all of the data
        let info = try readInfo(url: PersistenceCategory.info.url(directory: tmpDirectoryURL))
        Self.logger.debug("Read the info.json file")
        
        guard let infoData = info["data"] as? [String: Int] else {
            throw PersistenceCSVImporterError.fieldParsing("data")
        }
        Self.logger.debug("Got the available files from info.json: \(infoData)")
        
        let locations = try readLocations(directory: tmpDirectoryURL, infoData: infoData, progress: progress)
        Self.logger.debug("Read \(locations?.count ?? 0) locations")
        let alsCells = try readAlsCells(directory: tmpDirectoryURL, infoData: infoData, progress: progress)
        Self.logger.debug("Read \(alsCells?.count ?? 0) ALS cells")
        let packets = try readPackets(directory: tmpDirectoryURL, infoData: infoData, progress: progress)
        Self.logger.debug("Read \(packets?.count ?? 0) packets")
        let userCells = try readUserCells(directory: tmpDirectoryURL, infoData: infoData, progress: progress)
        Self.logger.debug("Read \(userCells?.count ?? 0) user cells")
        
        return ImportResult(cells: userCells, alsCells: alsCells, locations: locations, packets: packets, notices: [])
    }
    
    func fetchInfo(from url: URL) throws -> [String: Any] {
        // Get the file name from the persistence category
        let infoFile = PersistenceCategory.info.fileName()
        
        // This function call is required on iOS 16 to read files to be imported
        let securityScoped = url.startAccessingSecurityScopedResource()
        defer { if securityScoped { url.stopAccessingSecurityScopedResource() } }
        
        // Only extract the info.json from the archive
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw PersistenceCSVImporterError.cantOpenArchive(error)
        }
        
        // Get the file from the archive
        guard let entry = archive[infoFile] else {
            throw PersistenceCSVImporterError.infoMissing
        }
        
        // Create a temporary directory for extracting the file and remove it afterwards
        let tmpDirectoryURL = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: url, create: true)
        defer { try? FileManager.default.removeItem(at: tmpDirectoryURL) }
        
        // Extract the file from the ZIP archive to the temporary directory
        let tmpFileURL = tmpDirectoryURL.appendingPathComponent(infoFile)
        _ = try archive.extract(entry, to: tmpFileURL)
        
        // Read the file's content
        return try readInfo(url: tmpFileURL)
    }
    
    private func importData<T>(
        directory: URL,
        category: PersistenceCategory,
        infoData: [String: Int],
        progress: CSVProgressFunc,
        convert: (CSVReader) throws -> T?,
        timestamp: (T) -> Date?,
        bulkImport: ([T]) throws -> Void
    ) throws -> ImportCount? {
        // Append the category's prefix to the URL
        let url = directory.appendingPathComponent(category.fileName())
        Self.logger.debug("Importing data for \(String(describing: category)) from \(url)")
        
        // Check if the file exists, otherwise we'll just skip this category it
        guard FileManager.default.fileExists(atPath: url.path) else {
            Self.logger.debug("File doesn't exist for \(String(describing: category))")
            return nil
        }
        
        // Get the number of rows from the info file
        guard let infoRowCount = infoData[url.lastPathComponent] else {
            Self.logger.debug("The file exist, but is not in the info.json")
            throw PersistenceCSVImporterError.notInInfo
        }
        
        // Open the CSV file
        guard let stream = InputStream(url: url) else {
            Self.logger.debug("Can't create an InputStream for \(url)")
            throw PersistenceCSVImporterError.noInputStream
        }
        defer { stream.close() }
        
        // Open the CSV for reading
        let csv = try CSVReader(stream: stream, hasHeaderRow: true)
        
        // Read the CSV data and convert it into DB-ready objects which are then imported in bulk
        var dbReadyObjects: [T] = []
        var totalCounter = 0
        let beginEndDates = FirstLastDates()
        
        // Determine the size of each imported bulk
        let bulkSize = 1000
        
        // Initial progress update
        progress(category, 0, infoRowCount)
        
        Self.logger.debug("Start reading the entries of the file")
        
        // Read CSV line by line
        while csv.next() != nil {
            do {
                if let converted = try convert(csv) {
                    if let timestamp = timestamp(converted) {
                        beginEndDates.update(timestamp)
                    }
                    dbReadyObjects.append(converted)
                }
            } catch {
                Self.logger.info("Conversion of CSV line '\(csv.currentRow ?? [])' in file '\(category.fileName())' failed: \(error)")
            }
            
            // If there are enough objects read, we import a bulk of them into the DB
            if dbReadyObjects.count >= bulkSize {
                try bulkImport(dbReadyObjects)
                totalCounter += dbReadyObjects.count
                dbReadyObjects.removeAll()
                
                // Update the progress
                progress(category, totalCounter, infoRowCount)
            }
        }
        
        // Import the final bulk of objects
        try bulkImport(dbReadyObjects)
        totalCounter += dbReadyObjects.count
        dbReadyObjects.removeAll()
        
        // Update the progress (we'll just ignore all objects we've skipped)
        progress(category, infoRowCount, infoRowCount)
        
        Self.logger.debug("Finished an read \(totalCounter) entries from \(url)")
        
        // Return the total number of rows read
        return ImportCount(count: totalCounter, first: beginEndDates.first, last: beginEndDates.last)
    }
    
    private func readInfo(url: URL) throws -> [String: Any] {
        // Read the data from the extracted file
        let fileContents = try Data(contentsOf: url)
        
        // Turn the data into a Swift object
        let json = try JSONSerialization.jsonObject(with: fileContents)
        
        // Ensure the Swift has the correct type
        guard let jsonDict = json as? [String: Any] else {
            throw PersistenceCSVImporterError.infoWrongFormat
        }
        
        // Return it
        return jsonDict
    }
    
    private func readUserCells(directory: URL, infoData: [String: Int], progress: CSVProgressFunc) throws -> ImportCount? {
        let parser = CCTParser()
        
        // Think about also importing the cell's status and score
        
        return try importData(directory: directory, category: .connectedCells, infoData: infoData, progress: progress) { (csv: CSVReader) -> CCTCellProperties? in
            let jsonString = try csvString(csv, "json")
            
            guard let jsonData = jsonString.data(using: .utf8) else {
                throw PersistenceCSVImporterError.fieldNil("json")
            }
            
            guard let cellSample = try JSONSerialization.jsonObject(with: jsonData) as? CellSample else {
                throw PersistenceCSVImporterError.fieldJSONParsing("json")
            }
            
            return try parser.parse(cellSample)
        } timestamp: { sample in
            sample.timestamp
        } bulkImport: { samples in
            try PersistenceController.shared.importCollectedCells(from: samples)
        }
    }
    
    private func readAlsCells(directory: URL, infoData: [String: Int], progress: CSVProgressFunc) throws -> ImportCount? {
        return try importData(directory: directory, category: .alsCells, infoData: infoData, progress: progress) { csv in
            // let imported = try csvDate(csv, "imported")
            
            let technologyStr = try csvString(csv, "technology")
            let country = try csvInt(csv, "country")
            let network = try csvInt(csv, "network")
            let area = try csvInt(csv, "area")
            let cell = try csvInt(csv, "cell")
            let frequency = try csvInt(csv, "frequency")
            let physicalCell = try csvInt(csv, "physicalCell")
            
            let latitude = try csvDouble(csv, "latitude")
            let longitude = try csvDouble(csv, "longitude")
            let horizontalAccuracy = try csvDouble(csv, "horizontalAccuracy")
            let reach = try csvInt(csv, "reach")
            let score = try csvInt(csv, "score")
            
            guard let technology = ALSTechnology(rawValue: technologyStr) else {
                throw PersistenceCSVImporterError.fieldParsing("technology")
            }
            
            let alsLocation = ALSQueryLocation(fromImport: latitude, longitude: longitude, accuracy: Int(horizontalAccuracy), reach: reach, score: score)
            let alsCell = ALSQueryCell(
                fromImport: technology,
                country: Int32(country), network: Int32(network), area: Int32(area), cell: Int64(cell),
                physicalCell: Int32(physicalCell), frequency: Int32(frequency),
                location: alsLocation
            )
            
            return alsCell
        } timestamp: { sample in
            nil
        } bulkImport: { cells in
            try PersistenceController.shared.importALSCells(from: cells, source: nil)
        }
        
    }
    
    private func readLocations(directory: URL, infoData: [String: Int], progress: CSVProgressFunc) throws -> ImportCount? {
        return try importData(directory: directory, category: .locations, infoData: infoData, progress: progress) { (csv: CSVReader) -> TrackedUserLocation? in
            let collected = try csvDate(csv, "collected")
            
            let longitude = try csvDouble(csv, "longitude")
            let latitude = try csvDouble(csv, "latitude")
            let horizontalAccuracy = try csvDouble(csv, "horizontalAccuracy")
            
            let altitude = try csvDouble(csv, "altitude")
            let verticalAccuracy = try csvDouble(csv, "verticalAccuracy")
            
            let speed = try csvDouble(csv, "speed")
            let speedAccuracy = try csvDouble(csv, "speedAccuracy")
            
            let background = try csvBool(csv, "background")
            
            return TrackedUserLocation(timestamp: collected, latitude: latitude, longitude: longitude, horizontalAccuracy: horizontalAccuracy, altitude: altitude, verticalAccuracy: verticalAccuracy, speed: speed, speedAccuracy: speedAccuracy, background: background)
        } timestamp: { location in
            location.timestamp
        } bulkImport: { locations in
            try PersistenceController.shared.importUserLocations(from: locations)
        }
    }
    
    private func readPackets(directory: URL, infoData: [String: Int], progress: CSVProgressFunc) throws -> ImportCount? {
        // Set the packet retention time frame to infinite, so that older packets to-be-imported don't get deleted
        UserDefaults.standard.setValue(DeleteView.packetRetentionInfinite, forKey: UserDefaultsKeys.packetRetention.rawValue)
        UserDefaults.standard.setValue(DeleteView.locationRetentionInfinite, forKey: UserDefaultsKeys.locationRetention.rawValue)
        
        return try importData(directory: directory, category: .packets, infoData: infoData, progress: progress) { (csv: CSVReader) -> CPTPacket? in
            let directionStr = try csvString(csv, "direction")
            let dataStr = try csvString(csv, "data")
            let collected = try csvDate(csv, "collected")
            
            let direction = CPTDirection(rawValue: directionStr)
            let data = Data(base64Encoded: dataStr)
            
            guard let direction = direction, let data = data else {
                throw PersistenceCSVImporterError.fieldParsing("direction")
            }
            
            return try CPTPacket(direction: direction, data: data, timestamp: collected)
        } timestamp: { packet in
            packet.timestamp
        } bulkImport: { packets in
            let qmiPackets = packets.compactMap { packet -> (CPTPacket, ParsedQMIPacket)? in
                guard let qmiPacket = try? ParsedQMIPacket(nsData: packet.data) else {
                    return nil
                }
                
                return (packet, qmiPacket)
            }
            if qmiPackets.count > 0 {
                try PersistenceController.shared.importQMIPackets(from: qmiPackets)
            }
            
            let ariPackets = packets.compactMap { packet -> (CPTPacket, ParsedARIPacket)? in
                guard let qmiPacket = try? ParsedARIPacket(data: packet.data) else {
                    return nil
                }
                
                return (packet, qmiPacket)
            }
            if ariPackets.count > 0 {
                try PersistenceController.shared.importARIPackets(from: ariPackets)
            }
        }
    }
    
    
    
    private func csvDate(_ csv: CSVReader, _ key: String) throws -> Date {
        let timestamp = try csvDouble(csv, key)
        return Date(timeIntervalSince1970: timestamp)
    }
    
    private func csvInt(_ csv: CSVReader, _ key: String) throws -> Int {
        let intStr = try csvString(csv, key)
        
        if let int = Int(intStr) {
            return int
        } else {
            throw PersistenceCSVImporterError.fieldIntParsing(key)
        }
    }
    
    
    private func csvDouble(_ csv: CSVReader, _ key: String) throws -> Double {
        let doubleStr = try csvString(csv, key)
        
        if let double = Double(doubleStr) {
            return double
        } else {
            throw PersistenceCSVImporterError.fieldDoubleParsing(key)
        }
    }
    
    private func csvBool(_ csv: CSVReader, _ key: String) throws -> Bool {
        let boolStr = try csvString(csv, key)
        return boolStr.lowercased() == "true"
    }
    
    private func csvString(_ csv: CSVReader, _ key: String) throws -> String {
        // Get the string from the CSV
        guard let string = csv[key] else {
            throw PersistenceCSVImporterError.fieldMissing(key)
        }
        
        // Check that's it is not nil
        if string == "nil" {
            throw PersistenceCSVImporterError.fieldNil(key)
        }
        
        return string
    }
    
}
