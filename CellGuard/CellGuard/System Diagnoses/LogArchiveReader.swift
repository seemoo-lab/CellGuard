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

enum LogArchiveReadPhase: Int {
    case unarchiving = 0
    case extractingTar = 1
    case readingLogs = 2
    case finished = 3
}

struct LogArchiveReader {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: LogArchiveReader.self)
    )
    
    private static let rustApp = RustApp.init()
    
    static func importInBackground(url: URL, progress: @escaping (Int, Int) -> (), completion: @escaping (Result<Bool, Error>) -> ()) {
        Task(priority: TaskPriority.medium) {
            LogArchiveReader().read(url: url, rust: rustApp)
            
            DispatchQueue.main.async {
                completion(Result.success(true))
            }
            PortStatus.importActive.store(false, ordering: .relaxed)
        }
    }
    
    private let fileManager = FileManager.default
    
    // TODO: Supply state updates
    
    /*
     Unarchiving (Spinner)
     Extract files from tar (Spinner)
     Parsing logarchive files (Progress Indicator)
     Importing data (Progress Indicator)
     */
    
    func read(url: URL, rust: RustApp) {
        // TODO: Update progress
        do {
            let tmpDir = try createTmpDir()
            // Comment this out if you manually want to export the CSV file afterwards
            defer { Self.logger.debug("Remove temp dir"); try? fileManager.removeItem(at: tmpDir) }
            
            let tmpTarFile = try unarchive(url: url, tmpDir: tmpDir)
            
            guard let logArchive = try extractLogArchive(tmpDir: tmpDir, tmpTarFile: tmpTarFile) else {
                Self.logger.warning("No log archive dir")
                return
            }
            try fileManager.removeItem(at: tmpTarFile)
            
            guard let csvFile = try parseLogArchive(tmpDir: tmpDir, logArchiveDir: logArchive, rust: rust) else {
                Self.logger.warning("Read not successful")
                return
            }
            try fileManager.removeItem(at: logArchive)
            
            try readCSV(csvFile: csvFile)
            Self.logger.debug("done :)")
        } catch {
            Self.logger.warning("Error while getting stuff: \(error)")
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
        let unarchivedData = try Data(contentsOf: url).gunzipped()
        
        Self.logger.debug("Writing tar to FS")
        let tmpTarFile = tmpDir.appendingPathComponent("sysdiagnose.tar")
        try unarchivedData.write(to: tmpTarFile)
        Self.logger.debug("Wrote tar to \(tmpDir.absoluteString)")
        
        return tmpTarFile
    }
    
    private func extractLogArchive(tmpDir: URL, tmpTarFile: URL) throws -> URL? {
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
                print(path)
            }
        }
        
        let logArchiveDir = tmpDir.appendingPathComponent("system_logs.logarchive", conformingTo: .directory)
        print(logArchiveDir)
        
        if ((try? fileManager.subpathsOfDirectory(atPath: logArchiveDir.path)) ?? []).count == 0 {
            Self.logger.debug("No dir to read ):")
            return nil
        }
        
        return logArchiveDir
    }
    
    private func parseLogArchive(tmpDir: URL, logArchiveDir: URL, rust: RustApp) throws -> URL? {
        Self.logger.debug("Extracting stuff")
        
        let outFile = tmpDir.appendingPathComponent("system_logs", conformingTo: .commaSeparatedText)
        
        _ = rust.parse_system_log(logArchiveDir.path, outFile.path)

        return outFile
    }
    
    private func readCSV(csvFile: URL) throws {
        if let fileAttributes = try? fileManager.attributesOfItem(atPath: csvFile.path) {
            Self.logger.debug("\(fileAttributes))")
        }
        
        guard let inputStream = InputStream(url: csvFile) else {
            Self.logger.warning("No CSV input stream for \(csvFile)")
            return
        }
        
        let csvReader = try CSVReader(stream: inputStream, hasHeaderRow: true)
        var rowCount = 0
        while let row = csvReader.next() {
            // print("\(row)")
            rowCount += 1
        }
        
        // TODO: Read rows
        
        print("So many rows: \(rowCount)")
    }
    
}

func swift_parse_trace_file(path: RustStr, count: UInt32) {
    // TODO: Implement
    print("Swift: Already parsed \(count), now \(path.toString())")
}
