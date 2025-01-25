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

enum LogArchiveError: Error, LocalizedError {
    case createTmpDirFailed(Error)
    case unarchiveFailed(Error)
    case extractLogArchiveFailed(Error)
    case parseLogArchiveFailed(String)
    case deleteLogArchiveFailed(Error)
    case readCsvFailed(Error)
    case logArchiveDirEmpty
    case wrongCellPrefixText
    case wrongCellSuffixText
    case wrongCellJsonType
    case cellJsonConversionError(String, Error)
    case cellCCTParseError(String, Error)
    case noPacketProtocol
    case noBinaryPacketData
    case binaryPacketDataPrivate
    case binaryPacketDataDecodingError
    case importError(Error)
    
    var errorDescription: String? {
        switch self {
        case .createTmpDirFailed(_):
            return "Cannot create temporary directory."
        case .unarchiveFailed(_):
            return "Cannot unarchive the sysdiagnose."
        case .extractLogArchiveFailed(_):
            return "Cannot extract the logarchive from the sysdiagnose."
        case .deleteLogArchiveFailed(_):
            return "Cannot delete the logarchive."
        case .readCsvFailed(_):
            return "Cannot read the resulting csv file of the parsed logarchive."
        case .logArchiveDirEmpty:
            return "The logarchive directory is empty."
        case .parseLogArchiveFailed(_):
            return "The parsing of the logarchive failed."
        case .wrongCellPrefixText:
            return "A cell info has the wrong prefix."
        case .wrongCellSuffixText:
            return "A cell info has the wrong suffix."
        case .wrongCellJsonType:
            return "A cell info is not properly encoded JSON."
        case .cellJsonConversionError(_, _):
            return "Cannot parse a cell info as JSON."
        case .cellCCTParseError(_, _):
            return "Cannot extract data from a parsed cell info."
        case .noPacketProtocol:
            return "Missing the protocol for a baseband packet."
        case .noBinaryPacketData:
            return "Missing the binary data for a baseband packet."
        case .binaryPacketDataPrivate:
            return "The binary data of a packet is private."
        case .binaryPacketDataDecodingError:
            return "Cannot decode the data of a packet."
        case .importError(_):
            return "Failed to import the read cells & packets."
        }
    }
    
    var failureReason: String? {
        switch self {
        case let .createTmpDirFailed(error):
            return error.localizedDescription
        case let .unarchiveFailed(error):
            return error.localizedDescription
        case let .extractLogArchiveFailed(error):
            return error.localizedDescription
        case let .deleteLogArchiveFailed(error):
            return error.localizedDescription
        case let .readCsvFailed(error):
            return error.localizedDescription
        case let .parseLogArchiveFailed(errorStr):
            return errorStr
        case let .cellJsonConversionError(jsonStr, error):
            return "\(error.localizedDescription)\n\nJSON:\n\(jsonStr)"
        case let .cellCCTParseError(jsonStr, error):
            return "\(error.localizedDescription)\n\nJSON:\n\(jsonStr)"
        case let .importError(error):
            return error.localizedDescription
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .parseLogArchiveFailed(_):
            return "Please restart the app and try again."
        default:
            return nil
        }
    }
}

typealias LogProgressFunc = (LogArchiveReadPhase, Int, Int) -> Void

struct LogArchiveReader {
    
    static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: LogArchiveReader.self)
    )
    
    private static let rustApp = RustApp.init()
    public static var logParseProgress: (() -> Void)?
    
    static func importInBackground(url: URL, speedup: Bool, progress: @escaping LogProgressFunc, completion: @escaping (Result<ImportResult, Error>) -> ()) {
        // It's crucial that the task has not the lowest priority, otherwise the process is very slloooowww
        Task(priority: TaskPriority.high) {
            PortStatus.importActive.store(true, ordering: .relaxed)
            
            let localProgress: LogProgressFunc = { phase, cur, total in
                DispatchQueue.main.async {
                    progress(phase, cur, total)
                }
            }
            let result = Result.init {
                do {
                    return try LogArchiveReader().read(url: url, speedup: speedup, rust: rustApp, progress: localProgress)
                } catch {
                    logger.warning("Failed to read sysdiagnose \(url): \(error)")
                    throw error
                }
            }
            
            DispatchQueue.main.async {
                completion(result)
            }
            
            PortStatus.importActive.store(false, ordering: .relaxed)
        }
    }
    
    private let fileManager = FileManager.default
    
    func read(url: URL, speedup: Bool, rust: RustApp, progress: @escaping LogProgressFunc) throws -> ImportResult {
        Self.logger.debug("Reading log archive at \(url) with speedup = \(speedup)")
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
        var logArchive: URL
        var installedProfileDir: URL
        var speedup = speedup
        var fileCountTraceV3 = 0
        do {
            (logArchive, installedProfileDir) = try extractFromTar(tmpDir: tmpDir, tmpTarFile: tmpTarFile, speedup: speedup)
            fileCountTraceV3 = try countLogArchiveFiles(logArchiveDir: logArchive, speedup: speedup)
            
            // If the speed-up is enabled, check if the log archive has Persist or HighVolume tracev3 files.
            // If not, we can't apply the speed-up and have to scan all tracev3 files.
            if speedup && fileCountTraceV3 == 0 {
                Self.logger.debug("Disables Persist & HighVolume speed-up as there is none the relevant directories")
                speedup = false
                // Redo the extraction as we need all tracev3 files for parsing
                (logArchive, installedProfileDir) = try extractFromTar(tmpDir: tmpDir, tmpTarFile: tmpTarFile, speedup: speedup)
                fileCountTraceV3 = try countLogArchiveFiles(logArchiveDir: logArchive, speedup: speedup)
                // Disable the speed-up for future invocations as future sysdiagnoses recorded with the device will also not support the speed-up.
                // The user can always re-enable the speed-up in the settings.
                UserDefaults.standard.setValue(false, forKey: UserDefaultsKeys.logArchiveSpeedup.rawValue)
            }
            
            // Clean up tar file
            try fileManager.removeItem(at: tmpTarFile)
            // Clean up the app's inbox
            cleanupInbox()
        } catch {
            throw LogArchiveError.extractLogArchiveFailed(error)
        }
        
        var currentFileCount = 0
        Self.logParseProgress = {
            progress(.parsingLogs, currentFileCount, fileCountTraceV3)
            currentFileCount += 1
        }
        
        // Rust parses everything into the CSV file when we only need a few things from it.
        // macOS `log` command natively implements filters that make it faster.
        // Can we do the same? -> Yes, we already doing this in Rust.
        // The function `output` in the file `src/csv_parser.rs` filters log entries based on their subsystem and content.
        // Therefore, we have to modify the function if we want to analyze log entries of different subsystems.
        let csvFile = try parseLogArchive(tmpDir: tmpDir, logArchiveDir: logArchive, speedup: speedup, rust: rust)
        
        Self.logParseProgress = nil
        
        do {
            try fileManager.removeItem(at: logArchive)
            try fileManager.removeItem(at: installedProfileDir)
        } catch {
            throw LogArchiveError.deleteLogArchiveFailed(error)
        }
        
        do {
            let totalCsvLines = try countCSVLines(csvFile: csvFile)
            Self.logger.debug("Total CSV Lines: \(totalCsvLines)")
            var currentCsvLine = 0
            let out = try readCSV(csvFile: csvFile)
            {
                currentCsvLine += 1
                progress(.importingData, currentCsvLine, totalCsvLines)
            }
            Self.logger.debug("done :)")
            return out
        } catch {
            throw LogArchiveError.readCsvFailed(error)
        }
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
        // Request access to protected resources, i.e., files on disk shared by the user with the app
        let shouldCloseScope = url.startAccessingSecurityScopedResource()
        defer {
            if shouldCloseScope {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let unarchivedData = try Data(contentsOf: url).gunzipped()
        
        Self.logger.debug("Writing gunzipped tar to FS")
        let tmpTarFile = tmpDir.appendingPathComponent("sysdiagnose.tar")
        try unarchivedData.write(to: tmpTarFile)
        Self.logger.debug("Wrote tar to \(tmpDir.absoluteString)")
        
        return tmpTarFile
    }
    
    private func shouldExtractFile(nameComponents: [String.SubSequence], speedup: Bool) -> Bool {
        // There should be at least one filename present
        guard let last = nameComponents.last else {
            return false
        }
        
        if nameComponents.contains("system_logs.logarchive") {
            // Only extract HighVolume/*.travev3 & Persist/*.tracev3 files if the speedup is enabled
            if speedup && last.hasSuffix(".tracev3") {
                if nameComponents.contains("HighVolume") || nameComponents.contains("Persist") {
                    return true
                } else {
                    Self.logger.debug("Skipping extraction from tar due to speed up: \(nameComponents.joined(separator: "/"))")
                    return false
                }
            }
            
            // Extract all (other) files part of the logarchive
            return true
        } else if nameComponents.contains("MCState") {
            // Extract profile-[...].stub files
            if last.hasPrefix("profile-") && last.hasSuffix(".stub") {
                return true
            }
        }
        
        // Skip extraction of all other sysdiagnose files
        return false
    }
    
    private func extractFromTar(tmpDir: URL, tmpTarFile: URL, speedup: Bool) throws -> (logArchiveDir: URL, installedProfileDir: URL) {
        Self.logger.debug("Extracting tar contents")
        let fileHandle = try FileHandle(forReadingFrom: tmpTarFile)
        defer { try? fileHandle.close() }
        
        // Reading the TAR file sequentially from the disk
        // See: https://www.tsolomko.me/SWCompression/Structs/TarReader.html#/s:13SWCompression9TarReaderV7processyxxAA0B5EntryVSgKXEKlF
        var reader = TarReader(fileHandle: fileHandle)
        var cont = true
        while (cont) {
            try reader.process { entry in
                // Stop the reader if we've read all entries
                guard let entry = entry else {
                    cont = false
                    return
                }
                
                // Determine which files should be extracted to disk
                let nameComponents = entry.info.name.split(separator: "/")
                if !shouldExtractFile(nameComponents: nameComponents, speedup: speedup) {
                    return
                }
                
                // Remove the first directory layer from file structure, e.g. sysdiagnose_2024.09.15_11-45-25+0200_iPhone-OS_iPhone_21G93
                let path = nameComponents[1...nameComponents.count-1].reduce(tmpDir) { $0.appendingPathComponent(String($1)) }
                
                // Write file from tar archive to temporary directory
                try fileManager.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
                try entry.data?.write(to: path)
                Self.logger.debug("Extracting from tar: \(path)")
            }
        }
        
        let logArchiveDir = tmpDir.appendingPathComponent("system_logs.logarchive", conformingTo: .directory)
        Self.logger.debug("Log Archive Directory: \(logArchiveDir)")
        
        if ((try? fileManager.subpathsOfDirectory(atPath: logArchiveDir.path)) ?? []).count == 0 {
            Self.logger.debug("No log archive dir to read ):")
            throw LogArchiveError.logArchiveDirEmpty
        }
        
        let installedProfileDir = tmpDir
            .appendingPathComponent("logs", conformingTo: .directory)
            .appendingPathComponent("MCState", conformingTo: .directory)
            .appendingPathComponent("Shared", conformingTo: .directory)
        Self.logger.debug("Installed Profiles Directory: \(installedProfileDir)")
        
        return (logArchiveDir, installedProfileDir)
    }
    
    private func cleanupInbox() {
        // After unarchiving, shared sysdiagnose files are still in the app's folder .../Documents/Inbox/
        // Delete as mentioned in https://stackoverflow.com/questions/16213226/do-you-need-to-delete-imported-files-from-documents-inbox
        var dirPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        dirPath.append("/Inbox");
        if let directoryContents = try? fileManager.contentsOfDirectory(atPath: dirPath) {
            for path in directoryContents {
                let fullPath = (dirPath as NSString).appendingPathComponent(path)
                do {
                    try fileManager.removeItem(atPath: fullPath)
                    Self.logger.debug("Inbox file deleted: \(fullPath)")
                } catch let error as NSError {
                    Self.logger.warning("Error deleting files from inbox: \(error.localizedDescription)")
                }
            }
        }
    }
        
    private func countLogArchiveFiles(logArchiveDir: URL, speedup: Bool) throws -> Int {
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
                if speedup {
                    if fileUrl.pathComponents.contains("HighVolume") || fileUrl.pathComponents.contains("Persist") {
                        count += 1
                    }
                } else if !speedup {
                    count += 1
                }
            }
        }
        
        return count
    }
    
    private func parseLogArchive(tmpDir: URL, logArchiveDir: URL, speedup: Bool, rust: RustApp) throws -> URL {
        Self.logger.debug("Parsing extracted log archive using macos-unifiedlogs")
        
        // Define the path of the output file
        let outFile = tmpDir.appendingPathComponent("system_logs", conformingTo: .commaSeparatedText)
        
        // Call the native macos-unifiedlogs via swift-bridge
        // It the returns the total number of parsed log lines
        let (parsedFiles, rustErrorString) = rust.parse_system_log(logArchiveDir.path, outFile.path, speedup)
        
        // An error occurred while parsing the files.
        // See src/lib.rs for more information.
        if parsedFiles == UInt32.max {
            let swiftErrorString = rustErrorString.toString()
            Self.logger.warning("A Rust error occurred while parsing the log archive: \(swiftErrorString)")
            throw LogArchiveError.parseLogArchiveFailed(swiftErrorString)
        }

        return outFile
    }
    
    private func countCSVLines(csvFile: URL) throws -> Int {
        var count = 0
        try String(contentsOf: csvFile).enumerateLines { line, stop in
            count += 1
        }
        return count
    }
    
    private func readCSV(csvFile: URL, progress: () -> Void) throws -> ImportResult {
        if let fileAttributes = try? fileManager.attributesOfItem(atPath: csvFile.path) {
            Self.logger.debug("\(fileAttributes))")
        }
        
        guard let inputStream = InputStream(url: csvFile) else {
            Self.logger.warning("No CSV input stream for \(csvFile)")
            return ImportResult(cells: nil, alsCells: nil, locations: nil, packets: nil, notices: [])
        }
        
        let csvReader = try CSVReader(stream: inputStream, hasHeaderRow: true)
        
        // TODO: Import data during import (e.g. there are >1000 entries)
        var cells: [(CCTCellProperties, String)] = []
        var packets: [CPTPacket] = []
        let packetDates = FirstLastDates()
        var packetsPrivate: [Date] = []
        let packetPrivateDates = FirstLastDates()
        var skippedCount = 0
        
        while let row = csvReader.next() {
            if row.count < 5 {
                Self.logger.warning("Skipping CSV row as it has only \(row.count) rows (< 5): \(row)")
                progress()
                continue
            }
            
            let timestamp = Int(row[0])
            let subsystem = row[1]
            let library = row[2]
            let category = row[3]
            let message = row[4]
            
            guard let timestamp = timestamp else {
                Self.logger.warning("Skipped CSV row because of missing timestamp: \(row)")
                skippedCount += 1
                continue
            }
            let timestampDate = Date(timeIntervalSince1970: Double(timestamp) / Double(NSEC_PER_SEC))
            
            do {
                if category == "qmux" && subsystem == "com.apple.telephony.bb"  {
                    packets.append(try readCSVPacketQMI(library: library, timestamp: timestampDate, message: message))
                    packetDates.update(timestampDate)
                } else if category == "ARI" && subsystem == "com.apple.telephony.bb" {
                    packets.append(try readCSVPacketARI(library: library, timestamp: timestampDate, message: message))
                    packetDates.update(timestampDate)
                } else if category == "ct.server" && subsystem == "com.apple.CommCenter" {
                    cells.append(try readCSVCellMeasurement(timestamp: timestampDate, message: message))
                } else if subsystem == "com.apple.cache_delete" {
                    // TODO: Modify the function `output` in the file `src/csv_parser.rs` to include entries from this subsystem
                    readDeletedAction(timestamp: timestampDate, message: message)
                    skippedCount += 1
                } else {
                    skippedCount += 1
                }
            } catch LogArchiveError.binaryPacketDataPrivate {
                packetsPrivate.append(timestampDate)
                packetPrivateDates.update(timestampDate)
            } catch {
                skippedCount += 1
                Self.logger.warning("Skipped CSV row because of error (\(error)): \(row)")
            }
            progress()
        }
        
        // Remove cell measurements that aren't different to their predecessor of the last second.
        // This the same logic which is also implemented in the tweak.
        // See: https://dev.seemoo.tu-darmstadt.de/apple/cell-guard/-/blob/main/CaptureCellsTweak/CCTManager.m?ref_type=heads#L35
        
        // Store the properties of the previous cell in the list
        var prevCellDate: Date?
        var prevCellJson: String?
        let filteredCells = cells
            .sorted { $0.0.timestamp ?? Date.distantPast < $1.0.timestamp ?? Date.distantPast }
            .filter { (cell, cellJson) in
                if let prevCellDate = prevCellDate,
                   let prevCellJson = prevCellJson,
                   let cellDate = cell.timestamp,
                   cellDate.timeIntervalSince(prevCellDate) < 1,
                   prevCellJson == cellJson {
                    
                    return false
                }
                
                prevCellDate = cell.timestamp
                prevCellJson = cellJson
                
                return true
            }
            .map { $0.0 }
        Self.logger.debug("Filtered \(cells.count - filteredCells.count) similar cells, resulting in \(cells.count) cells.")

        
        do {
            let controller = PersistenceController.basedOnEnvironment()
            if cells.count > 0 {
                try controller.importCollectedCells(from: filteredCells)
            }
            if packets.count > 0 {
                _ = try CPTCollector.store(packets)
            }
        } catch {
            throw LogArchiveError.importError(error)
        }
        
        // TODO: Recently installed and recently expired (check MCProfileEvents.plist)
        // TODO: Check for log truncation
        
        return ImportResult(
            cells: ImportCount(count: filteredCells.count, first: filteredCells.first?.timestamp, last: filteredCells.last?.timestamp),
            alsCells: nil,
            locations: nil,
            packets: ImportCount(count: packets.count, first: packetDates.first, last: packetDates.last),
            notices: []  // TODO: currently no more notices, as we don't check profile here
        )
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
        
        return try CPTPacket(direction: direction, data: packetData, timestamp: timestamp, knownProtocol: .qmi)
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
        
        return try CPTPacket(direction: direction, data: packetData, timestamp: timestamp, knownProtocol: .ari)
    }
    
    private let regexInt = Regex("kCTCellMonitor([\\w\\d]+) *= *(\\d+);")
    private let replaceInt = "\"$1\": $2,"
    
    private let regexString = Regex("kCTCellMonitor([\\w]+) *= *kCTCellMonitor([a-zA-Z][\\w\\d]*);")
    private let regexStringQuoted = Regex("kCTCellMonitor([\\w]+) *= *\\\\\"([\\S]+)\\\\\";")
    private let replaceString = "\"$1\": \"$2\","
    
    private func readCSVCellMeasurement(timestamp: Date, message: String) throws -> (CCTCellProperties, String) {
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
            return (try CCTParser().parse(json), jsonMsg)
        } catch {
            throw LogArchiveError.cellCCTParseError(jsonMsg, error)
        }
    }
    
    // TODO: check if this really detects deleted log entries
    // TODO: show UI warning to the user that their disk might be too full
    private func readDeletedAction(timestamp: Date, message: String) {
        // TODO: Modify the function `output` in the file `src/csv_parser.rs` to include entries from the subsystem
        
        // We're looking for a logd flush like this:
        // com.apple.logd.cachedelete : 666287008
        
        let deleteRegex = Regex("^com.apple.logd.cachedelete : ([0-9]*)")
        
        guard let deleteMatch = deleteRegex.firstMatch(in: message) else {
            return
        }
        // this might also be the maximum log size in bytes not the number of entries purged
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
