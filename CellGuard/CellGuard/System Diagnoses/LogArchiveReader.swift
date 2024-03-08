//
//  LogArchiveReader.swift
//  CellGuard
//
//  Created by Lukas Arnold on 17.12.23.
//

import Foundation
import Gzip
import SWCompression
import OSLog
import CSV
import Regex


enum LogArchiveReadPhase: Int {
    // Spinner
    case unarchiving = 0
    // Extract files from tar (Spinner)
    case extractingTar = 1
    // Parsing logarchive files (Progress Indicator)
    case parsingLogs = 2
    // Importing data (Progress Indicator)
    case importingData = 3
}

enum LogArchiveError: Error {
    case createTmpDirFailed(Error)
    case unarchiveFailed(Error)
    case extractLogArchiveFailed(Error)
    case parseLogArchiveFailed(Error)
    case readCsvFailed(Error)
    case logArchiveDirEmpty
    case parsingFailed
    case wrongCellPrefixText
    case wrongCellSuffixText
    case wrongCellJsonType
    case cellJsonConversionError(String, Error)
    case cellCCTParseError(String, Error)
    case noPacketProtocol
    case noBinaryPacketData
    case binaryPacketDataPrivate
    case binaryPacketDataDecodingError
    case timestampNoInt
    case importError(Error)
}

typealias LogProgressFunc = (LogArchiveReadPhase, Int, Int) -> Void
typealias ArchiveReadResult = (cells: Int, packets: Int, skipped: Int)

struct LogArchiveReader {
    
    static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: LogArchiveReader.self)
    )
    
    private static let rustApp = RustApp.init()
    public static var logParseProgress: (() -> Void)?
    
    static func importInBackground(url: URL, progress: @escaping LogProgressFunc, completion: @escaping (Result<ImportResult, Error>) -> ()) {
        // It's crucial that the task has not the lowest priority, otherwise the process is very slloooowww
        Task(priority: TaskPriority.high) {
            PortStatus.importActive.store(true, ordering: .relaxed)
            
            let localProgress: LogProgressFunc = { phase, cur, total in
                DispatchQueue.main.async {
                    progress(phase, cur, total)
                }
            }
            let result = try LogArchiveReader().read(url: url, rust: rustApp, progress: localProgress)
            
            DispatchQueue.main.async {
                completion(Result.success(result))
            }
            
            PortStatus.importActive.store(false, ordering: .relaxed)
        }
    }
    
    private let fileManager = FileManager.default
    
    func read(url: URL, rust: RustApp, progress: @escaping LogProgressFunc) throws -> ImportResult {
        progress(.unarchiving, 0, 0)
        let tmpDir: URL
        do {
            tmpDir = try createTmpDir()
        } catch {
            throw LogArchiveError.createTmpDirFailed(error)
        }
        // Comment this out if you manually want to export the CSV file afterwards
        defer { Self.logger.debug("Remove temp dir"); try? fileManager.removeItem(at: tmpDir) }
        
        let tmpTarFile: URL
        do {
            tmpTarFile = try unarchive(url: url, tmpDir: tmpDir)
        } catch {
            throw LogArchiveError.unarchiveFailed(error)
        }
        
        progress(.extractingTar, 0, 0)
        let logArchive: URL
        do {
            logArchive = try extractLogArchive(tmpDir: tmpDir, tmpTarFile: tmpTarFile)
            try fileManager.removeItem(at: tmpTarFile)
        } catch {
            throw LogArchiveError.extractLogArchiveFailed(error)
        }
        
        let csvFile: URL
        do {
            let totalFileCount = try countLogArchiveFiles(logArchiveDir: logArchive)
            var currentFileCount = 0
            Self.logParseProgress = {
                progress(.parsingLogs, currentFileCount, totalFileCount)
                currentFileCount += 1
            }
            
            // TODO: Can we speed this up?
            // Rust parses everything into the CSV file when we only need a few things from it.
            // macOS `log` command natively implements filters that make it faster.
            // Can we do the same?
            csvFile = try parseLogArchive(tmpDir: tmpDir, logArchiveDir: logArchive, rust: rust)
            
            Self.logParseProgress = nil
            try fileManager.removeItem(at: logArchive)
        } catch {
            throw LogArchiveError.parseLogArchiveFailed(error)
        }
        
        do {
            let totalCsvLines = try countCSVLines(csvFile: csvFile)
            Self.logger.debug("Total CSV Lines: \(totalCsvLines)")
            var currentCsvLine = 0
            let out = try readCSV(csvFile: csvFile) {
                currentCsvLine += 1
                progress(.importingData, currentCsvLine, totalCsvLines)
            }
            Self.logger.debug("done :)")
            return (cells: out.cells, alsCells: 0, locations: 0, packets: out.packets)
        } catch {
            throw LogArchiveError.readCsvFailed(error)
        }
        
        // TODO: in a final step, merge duplicates from coredata
    }
    
    private func createTmpDir() throws -> URL {
        // Create a temporary directory which is deleted at the end of this method
        // See: https://nshipster.com/temporary-files/
        
        let tmpDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, conformingTo: .directory)
        try fileManager.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        
        Self.logger.debug("Created temporary directory at \(tmpDir)")
        
        return tmpDir
    }
    
    private func unarchive(url: URL, tmpDir: URL) throws -> URL {
        let unarchivedData = try Data(contentsOf: url).gunzipped()
        
        Self.logger.debug("Writing tar to FS")
        let tmpTarFile = tmpDir.appendingPathComponent("sysdiagnose.tar")
        try unarchivedData.write(to: tmpTarFile)
        Self.logger.debug("Wrote tar to \(tmpDir.absoluteString)")
        
        return tmpTarFile
    }
    
    private func extractLogArchive(tmpDir: URL, tmpTarFile: URL) throws -> URL {
        Self.logger.debug("Reading tar stuff")
        let fileHandle = try FileHandle(forReadingFrom: tmpTarFile)
        defer { try? fileHandle.close() }
        
        // Reading the TAR file sequentially from the disk
        // See: https://www.tsolomko.me/SWCompression/Structs/TarReader.html#/s:13SWCompression9TarReaderV7processyxxAA0B5EntryVSgKXEKlF
        var reader = TarReader(fileHandle: fileHandle)
        var cont = true
        while (cont) {
            try reader.process { entry in
                guard let entry = entry else {
                    cont = false
                    return
                }
                
                let nameComponents = entry.info.name.split(separator: "/")
                guard let logArchiveIndex = nameComponents.lastIndex(of: "system_logs.logarchive") else {
                    return
                }
                
                let path = nameComponents[logArchiveIndex...nameComponents.count-1]
                    .reduce(tmpDir) { $0.appendingPathComponent(String($1)) }
                
                try fileManager.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
                try entry.data?.write(to: path)
                Self.logger.debug("Extracting from TAR: \(path)")
            }
        }
        
        let logArchiveDir = tmpDir.appendingPathComponent("system_logs.logarchive", conformingTo: .directory)
        Self.logger.debug("Log Archive Directory: \(logArchiveDir)")
        
        if ((try? fileManager.subpathsOfDirectory(atPath: logArchiveDir.path)) ?? []).count == 0 {
            Self.logger.debug("No log archive dir to read ):")
            throw LogArchiveError.logArchiveDirEmpty
        }
        
        // After unarchiving, shared sysdiagnoes files are still in the app's folder .../Documents/Inbox/
        // Delete as mentioned in https://stackoverflow.com/questions/16213226/do-you-need-to-delete-imported-files-from-documents-inbox
        var dirPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        dirPath.append("/Inbox");
        if let directoryContents = try? fileManager.contentsOfDirectory(atPath: dirPath)
        {
            for path in directoryContents
            {
                let fullPath = (dirPath as NSString).appendingPathComponent(path)
                do
                {
                    try fileManager.removeItem(atPath: fullPath)
                    print("Inbox file deleted!")
                }
                catch let error as NSError
                {
                    print("Error deleting files from inbox: \(error.localizedDescription)")
                }
            }
        }
        
        return logArchiveDir
    }
        
    private func countLogArchiveFiles(logArchiveDir: URL) throws -> Int {
        // See: https://stackoverflow.com/a/41979314
        let resourceKeys : [URLResourceKey] = [.isDirectoryKey]
        guard let enumerator = fileManager.enumerator(at: logArchiveDir, includingPropertiesForKeys: resourceKeys) else {
            return 0
        }
        
        var count = 0
        for case let fileUrl as URL in enumerator {
            let resourceValues = try fileUrl.resourceValues(forKeys: Set(resourceKeys))
            // We don't count directories
            if resourceValues.isDirectory ?? false {
                continue
            }
            // We search for files which will be parsed by the library
            if fileUrl.lastPathComponent.hasSuffix(".tracev3") {
                count += 1
            }
        }
        
        return count
    }
    
    private func parseLogArchive(tmpDir: URL, logArchiveDir: URL, rust: RustApp) throws -> URL {
        Self.logger.debug("Extracting stuff")
        
        // Define the path of the output file
        let outFile = tmpDir.appendingPathComponent("system_logs", conformingTo: .commaSeparatedText)
        
        // Call the native macos-unifiedlogs via swift-bridge
        // It the returns the total number of parsed log lines
        _ = rust.parse_system_log(logArchiveDir.path, outFile.path)

        return outFile
    }
    
    private func countCSVLines(csvFile: URL) throws -> Int {
        var count = 0
        try String(contentsOf: csvFile).enumerateLines { line, stop in
            count += 1
        }
        return count
    }
    
    private func readCSV(csvFile: URL, progress: () -> Void) throws -> ArchiveReadResult {
        if let fileAttributes = try? fileManager.attributesOfItem(atPath: csvFile.path) {
            Self.logger.debug("\(fileAttributes))")
        }
        
        guard let inputStream = InputStream(url: csvFile) else {
            Self.logger.warning("No CSV input stream for \(csvFile)")
            return (0, 0, 0)
        }
        
        let csvReader = try CSVReader(stream: inputStream, hasHeaderRow: true)
        
        // TODO: Import data during import (e.g. there are >1000 entries)
        var cells: [CCTCellProperties] = []
        var packets: [CPTPacket] = []
        var skippedCount = 0
        
        while let row = csvReader.next() {
            if row.count < 14 {
                Self.logger.warning("Skipping CSV row as it has only \(row.count) rows (< 14): \(row)")
                progress()
                continue
            }
            
            let timestamp = Int(row[0])
            let subsystem = row[3]
            let library = row[7]
            let category = row[10]
            let message = row[13]
            
            do {
                guard let timestamp = timestamp else {
                    throw LogArchiveError.timestampNoInt
                }
                let timestampDate = Date(timeIntervalSince1970: Double(timestamp) / Double(NSEC_PER_SEC))
                
                if category == "qmux" && subsystem == "com.apple.telephony.bb"  {
                    packets.append(try readCSVPacketQMI(library: library, timestamp: timestampDate, message: message))
                } else if category == "ARI" && subsystem == "com.apple.telephony.bb" {
                    packets.append(try readCSVPacketARI(library: library, timestamp: timestampDate, message: message))
                } else if category == "ct.server" && subsystem == "com.apple.CommCenter" {
                    cells.append(try readCSVCellMeasurement(timestamp: timestampDate, message: message))
                } else if subsystem == "com.apple.cache_delete" {
                    readDeletedAction(timestamp: timestampDate, message: message)
                    skippedCount += 1
                } else {
                    skippedCount += 1
                }
            } catch LogArchiveError.binaryPacketDataPrivate {
                skippedCount += 1
                // Maybe warn the user if all packets are private, so they reinstall the profile
            } catch {
                skippedCount += 1
                Self.logger.warning("Skipped CSV row because of error (\(error)): \(row)")
            }
            progress()
        }
        
        do {
            let controller = PersistenceController.basedOnEnvironment()
            if cells.count > 0 {
                try controller.importCollectedCells(from: cells)
            }
            if packets.count > 0 {
                _ = try CPTCollector.store(packets)
            }
        } catch {
            throw LogArchiveError.importError(error)
        }
        
        
        return (cells.count, packets.count, skippedCount)
    }
    
    
    private func readCSVPacketQMI(library: String, timestamp: Date, message: String) throws -> CPTPacket {
        
        // speed up regex by being more precise about its start
        let binRegex = Regex("^QMI: Svc=0x.*Bin=\\[(.*)]")
        guard let binMatch = binRegex.firstMatch(in: message) else {
            throw LogArchiveError.noBinaryPacketData
        }
        if binMatch.captures.isEmpty {
            throw LogArchiveError.noBinaryPacketData
        }
        guard let binString = binMatch.captures[0] else {
            throw LogArchiveError.noBinaryPacketData
        }
        if binString == "<private>" {
            throw LogArchiveError.binaryPacketDataPrivate
        }
        guard let packetData = Data(base64Encoded: binString) else {
            throw LogArchiveError.binaryPacketDataDecodingError
        }
        
        let direction: CPTDirection
        direction = message.contains("Req") ? .outgoing : .ingoing
        
        return try CPTPacket(direction: direction, data: packetData, timestamp: timestamp)
    }
    
    
    private func readCSVPacketARI(library: String, timestamp: Date, message: String) throws -> CPTPacket {
        
        let binRegex = Regex("(ind|req|rsp): Bin=\\[(.*)]")
        guard let binMatch = binRegex.firstMatch(in: message) else {
            throw LogArchiveError.noBinaryPacketData
        }
        if binMatch.captures.isEmpty {
            throw LogArchiveError.noBinaryPacketData
        }
        guard let binString = binMatch.captures[1] else {
            throw LogArchiveError.noBinaryPacketData
        }
        if binString == "<private>" {
            throw LogArchiveError.binaryPacketDataPrivate
        }
        guard let packetData = Data(base64Encoded: binString) else {
            throw LogArchiveError.binaryPacketDataDecodingError
        }
        
        let direction: CPTDirection
        direction = message.contains("req") ? .outgoing : .ingoing
        
        return try CPTPacket(direction: direction, data: packetData, timestamp: timestamp)
    }
    
    private let regexInt = Regex("kCTCellMonitor([\\w\\d]+) *= *(\\d+);")
    private let replaceInt = "\"$1\": $2,"
    
    private let regexString = Regex("kCTCellMonitor([\\w]+) *= *kCTCellMonitor([a-zA-Z][\\w\\d]*);")
    private let regexStringQuoted = Regex("kCTCellMonitor([\\w]+) *= *\\\\\"([\\S]+)\\\\\";")
    private let replaceString = "\"$1\": \"$2\","
    
    private func readCSVCellMeasurement(timestamp: Date, message: String) throws -> CCTCellProperties {
        let messageBodySuffix = message.components(separatedBy: "info=(")
        if messageBodySuffix.count < 2 {
            throw LogArchiveError.wrongCellPrefixText
        }
        // Remove the final closing parentheses
        let messageBody = messageBodySuffix[1].trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        
        // TODO:        kCTCellMonitorRSSI = \"-96\";
        
        var jsonMsg = messageBody
        // Escape all the existing quotes
        jsonMsg = jsonMsg.replacingOccurrences(of: "\"", with: "\\\"")
        // Convert the description format to JSON (while also removing the prefix kCT as the tweak does)
        jsonMsg.replaceAll(matching: regexInt, with: replaceInt)
        jsonMsg.replaceAll(matching: regexString, with: replaceString)
        jsonMsg.replaceAll(matching: regexStringQuoted, with: replaceString)
        // Replace the sounding parentheses to convert it to a JSON array
        jsonMsg = jsonMsg.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        jsonMsg = "[\(jsonMsg)]"
        // Self.logger.debug("JSON-ready cell measurement: \(jsonMsg)")
        
        // Try to parse our Frankenstein JSON string
        let json: CellSample?
        do {
            json = try JSONSerialization.jsonObject(with: jsonMsg.data(using: .utf8)!) as? CellSample
        } catch {
            throw LogArchiveError.cellJsonConversionError(jsonMsg, error)
        }
        guard var json = json else {
            throw LogArchiveError.wrongCellJsonType
        }
        
        // Append the timestamp
        json.append(["timestamp": timestamp.timeIntervalSince1970])
        
        // Parse the JSON dictionary with our own parser
        do {
            return try CCTParser().parse(json)
        } catch {
            throw LogArchiveError.cellCCTParseError(jsonMsg, error)
        }
    }
    
    // TODO: check if this really detects deleted log entries
    // TODO: show UI warning to the user that their disk might be too full
    private func readDeletedAction(timestamp: Date, message: String) {
        // We're looking for a logd flush like this:
        // com.apple.logd.cachedelete : 666287008
        
        let deleteRegex = Regex("^com.apple.logd.cachedelete : ([0-9]*)")
        
        guard let deleteMatch = deleteRegex.firstMatch(in: message) else {
            return
        }
        guard let deletedEntries = deleteMatch.captures[0] else {
            return
        }
        LogArchiveReader.logger.debug("delted entries match \(deletedEntries)")
        guard let deletedEntries = Int(deletedEntries) else {
            return
        }
        
        // TODO: throw error and show warning to user
        if deletedEntries > 0 {
            LogArchiveReader.logger.error("deleted purged \(deletedEntries) log entries at \(timestamp)!!")
        }
        
    }
}

func swift_parse_trace_file(path: RustStr, count: UInt32) {
    LogArchiveReader.logger.debug("Swift: Already parsed \(count) lines, parsing now file \(path.toString())")
    LogArchiveReader.logParseProgress?()
}
