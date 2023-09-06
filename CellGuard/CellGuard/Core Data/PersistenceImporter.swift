//
//  PersistenceImporter.swift
//  CellGuard
//
//  Created by Lukas Arnold on 24.01.23.
//

import Foundation
import OSLog

enum PersistenceImportError: Error {
    case permissionDenied
    case iCloudDownload
    case readFailed(Error)
    case deserilizationFailed(Error)
    case invalidStructure
    case locationImportFailed(Error)
    case cellImportFailed(Error)
}

extension PersistenceImportError: LocalizedError {
    
    var errorDescription: String? {
        switch (self) {
        case .permissionDenied: return "Permission Denied"
        case .iCloudDownload: return "Download the file from iCloud using the Files app before opening it."
        case let .readFailed(error): return "Read Failed (\(error.localizedDescription))"
        case let .deserilizationFailed(error): return "Derserilization Failed (\(error.localizedDescription))"
        case .invalidStructure: return "Invalid JSON Structure"
        case let .locationImportFailed(error): return "Location Import Failed (\(error.localizedDescription))"
        case let .cellImportFailed(error): return "Cell Import Failed (\(error.localizedDescription))"
        }
    }
    
}

// https://stackoverflow.com/a/49154838
// https://developer.apple.com/documentation/uniformtypeidentifiers/defining_file_and_data_types_for_your_app
// https://developer.apple.com/documentation/uniformtypeidentifiers/uttype/3551524-json
// https://stackoverflow.com/questions/69499921/adding-file-icon-to-custom-file-type-in-xcode
// https://developer.apple.com/documentation/uikit/view_controllers/adding_a_document_browser_to_your_app/setting_up_a_document_browser_app

struct PersistenceImporter {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: PersistenceImporter.self)
    )
    
    // Provide synchronized access to the import active variable
    // See: https://stackoverflow.com/a/65849172
    private static let importLock = NSLock()
    private static var _importActive = false
    static var importActive: Bool {
        get {
            importLock.lock()
            defer { importLock.unlock() }
            return _importActive
        }
        set {
            importLock.lock()
            defer { importLock.unlock() }
            _importActive = newValue
        }
    }
    
    static func importInBackground(
        url: URL,
        progress: @escaping (Int, Int) -> Void,
        completion: @escaping (Result<(cells: Int, locations: Int, packets: Int), Error>) -> Void
    ) {
        importActive = true
        
        var internalProgressCount = 0
        let progressMax = 4
        
        progress(0, progressMax)
        
        let internalProgress = {
            DispatchQueue.main.async {
                internalProgressCount += 1
                progress(internalProgressCount, progressMax)
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result.init {
                try PersistenceImporter().importData(from: url, progress: internalProgress)
            }
            DispatchQueue.main.async {
                completion(result)
            }
            importActive = false
        }
    }
    
    private init() {
        
    }
    
    private func importData(from url: URL, progress: @escaping () -> Void) throws -> (cells: Int, locations: Int, packets: Int) {
        let data = try read(url: url)
        progress()
        return try store(json: data, progress: progress)
    }
    
    private func read(url: URL) throws -> [String: Any] {
        // This function call is required on iOS 16 to read files to be imported
        guard url.startAccessingSecurityScopedResource() else {
            throw PersistenceImportError.permissionDenied
        }
        
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            // Due to the entry "Supports opening documents in place" in Info.plist,
            // the Files app also directly opens non-downloaded files from iCloud.
            // But they have to be downloaded first, before they can be used.
            // TODO: Implement automatic download
            // See: https://developer.apple.com/documentation/foundation/filemanager/1410377-startdownloadingubiquitousitem
            // See: https://stackoverflow.com/a/63531485
            if FileManager.default.isUbiquitousItem(at: url) {
                throw PersistenceImportError.iCloudDownload
            }
            
            throw PersistenceImportError.readFailed(error)
        }
        
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw PersistenceImportError.deserilizationFailed(error)
        }
        
        
        guard let jsonDict = json as? [String: Any] else {
            throw PersistenceImportError.invalidStructure
        }
        
        return jsonDict
    }
    
    private func store(json: [String : Any], progress: () -> Void) throws -> (cells: Int, locations: Int, packets: Int) {
        let locations = try storeLocations(json: json)
        progress()
        let cells = try storeCells(json: json)
        progress()
        let packets = try storePackets(json: json)
        progress()
        
        Self.logger.debug("Imported \(locations) locations, \(cells) cells, \(packets.qmi) QMI packets, and \(packets.ari) ARI packets")
        
        return (cells, locations, packets.qmi + packets.ari)
    }
    
    private func storeLocations(json: [String : Any]) throws -> Int {
        let locationsJson: [Any] = (json[CellFileKeys.locations] as? [Any]) ?? []
        
        let locations = locationsJson
            .compactMap { $0 as? [String: Any] }
            .map { TrackedUserLocation(from: $0) }
        
        try PersistenceController.shared.importUserLocations(from: locations)
        
        return locations.count
    }
    
    private func storeCells(json: [String : Any]) throws -> Int {
        let parser = CCTParser()
        let cellsJson: [Any] = (json[CellFileKeys.connectedCells] as? [Any]) ?? []
        
        let cells = cellsJson
            .compactMap { $0 as? CellSample }
            .compactMap { (sample: CellSample) in
                do {
                    return try parser.parse(sample)
                } catch {
                    Self.logger.warning("Skipped cell sample \(sample) for import: \(error)")
                    return nil
                }
            }
        
        try PersistenceController.shared.importCollectedCells(from: cells)
        
        return cells.count
    }
    
    private func storePackets(json: [String : Any]) throws -> (qmi: Int, ari: Int) {
        let packetsJson: [Any] = (json[CellFileKeys.packets] as? [Any]) ?? []
        
        let packets = try packetsJson
            .compactMap { (jsonElement: Any) -> CPTPacket? in
                guard let packetJson = jsonElement as? [String: Any] else {
                    Self.logger.warning("Skipped packet \(String(describing: jsonElement)) as there were no elements")
                    return nil
                }
                
                let directionStr = packetJson[PacketDictKeys.direction] as? String
                let dataStr = packetJson[PacketDictKeys.data] as? String
                let collectedDouble = packetJson[PacketDictKeys.collected] as? Double
                
                guard let directionStr = directionStr, let dataStr = dataStr, let collectedDouble = collectedDouble else {
                    Self.logger.warning("Skipped packet \(packetJson) as some data was missing")
                    return nil
                }
                
                let direction = CPTDirection(rawValue: directionStr)
                let data = Data(base64Encoded: dataStr)
                let collected = Date(timeIntervalSince1970: collectedDouble)
                
                guard let direction = direction, let data = data else {
                    Self.logger.warning("Skipped packet \(packetJson) as some data was invalid")
                    return nil
                }
                
                return try CPTPacket(direction: direction, data: data, timestamp: collected)
            }
        
        // Set the packet retention time frame to infinite, so that older packets to-be-imported don't get deleted
        UserDefaults.standard.setValue(DeleteView.packetRetentionInfinite, forKey: UserDefaultsKeys.packetRetention.rawValue)
        
        let qmiPackets = packets.compactMap { packet -> (CPTPacket, ParsedQMIPacket)? in
            guard let qmiPacket = try? ParsedQMIPacket(nsData: packet.data) else {
                return nil
            }
            
            return (packet, qmiPacket)
        }
        
        try PersistenceController.shared.importQMIPackets(from: qmiPackets)
        
        let ariPackets = packets.compactMap { packet -> (CPTPacket, ParsedARIPacket)? in
            guard let qmiPacket = try? ParsedARIPacket(data: packet.data) else {
                return nil
            }
            
            return (packet, qmiPacket)
        }

        try PersistenceController.shared.importARIPackets(from: ariPackets)
        
        return (qmi: qmiPackets.count, ari: ariPackets.count)
    }
    
}
