//
//  LogArchiveReader.swift
//  IosUnifiedLogs
//
//  Created by Lukas Arnold on 29.07.23.
//

import Foundation
import Gzip
import SWCompression

struct LogArchiveReader {
    
    private let fileManager = FileManager.default
    
    // TODO: Supply state updates
    
    func read(url: URL, rust: RustApp) {
        do {
            let tmpDir = try createTmpDir()
            // Comment this out if you manually want to export the CSV file afterwards
            defer { print("Remove temp dir"); try? fileManager.removeItem(at: tmpDir) }
            
            let tmpTarFile = try unarchive(url: url, tmpDir: tmpDir)
            
            guard let logArchive = try extractLogArchive(tmpDir: tmpDir, tmpTarFile: tmpTarFile) else {
                print("No log archive dir")
                return
            }
            try fileManager.removeItem(at: tmpTarFile)
            
            guard let csvFile = try parseLogArchive(tmpDir: tmpDir, logArchiveDir: logArchive, rust: rust) else {
                print("Read not successful")
                return
            }
            try fileManager.removeItem(at: logArchive)
            
            try readCSV(csvFile: csvFile)
            print("done :)")
        } catch {
            print("Error while getting stuff: \(error)")
        }
    }
    
    private func createTmpDir() throws -> URL {
        // Create a temporary directory which is deleted at the end of this method
        // See: https://nshipster.com/temporary-files/
        
        let tmpDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, conformingTo: .directory)
        try fileManager.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        
        print("Created temporary directory at \(tmpDir)")
        
        return tmpDir
    }
    
    private func unarchive(url: URL, tmpDir: URL) throws -> URL {
        let unarchivedData = try Data(contentsOf: url).gunzipped()
        
        print("Writing tar to FS")
        let tmpTarFile = tmpDir.appendingPathComponent("sysdiagnose.tar")
        try unarchivedData.write(to: tmpTarFile)
        print("Wrote tar to \(tmpDir.absoluteString)")
        
        return tmpTarFile
    }
    
    private func extractLogArchive(tmpDir: URL, tmpTarFile: URL) throws -> URL? {
        print("Reading tar stuff")
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
            print("No dir to read ):")
            return nil
        }
        
        return logArchiveDir
    }
    
    private func parseLogArchive(tmpDir: URL, logArchiveDir: URL, rust: RustApp) throws -> URL? {
        print("Extracting stuff")
        
        let outFile = tmpDir.appendingPathComponent("system_logs", conformingTo: .commaSeparatedText)
        
        _ = rust.parse_system_log(logArchiveDir.path, outFile.path)

        return outFile
    }
    
    private func readCSV(csvFile: URL) throws {
        print(try fileManager.attributesOfItem(atPath: csvFile.path))
        
        // TODO: Read
        // See: https://github.com/swiftcsv/SwiftCSV
    }
    
}
