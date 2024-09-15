//
//  ProfileScanner.swift
//  CellGuard
//
//  Created by Lukas Arnold on 15.09.24.
//

import Foundation
import OSLog

struct ProfileStubData: Codable, CustomStringConvertible {
    let payloadIdentifier: String?
    let installDate: Date?
    let removalDate: Date?
    
    // Map uppercase property list keys to lower case struct names
    // See: https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types#2904057
    enum CodingKeys: String, CodingKey {
        case payloadIdentifier = "PayloadIdentifier"
        case installDate = "InstallDate"
        case removalDate = "RemovalDate"
    }
    
    var description: String {
        return "ProfileStubData(payloadIdentifier=\(String(describing: payloadIdentifier)),installDate=\(String(describing: installDate)),removalDate=\(String(describing: removalDate))"
    }
}

enum ProfileScannerError: Error, LocalizedError {
    case CantReadStub(URL, Error)
    
    var errorDescription: String? {
        switch self {
        case .CantReadStub(_, _):
            return "Can't read profile stub file"
        }
    }
    
    var failureReason: String? {
        switch self {
        case let .CantReadStub(url, error):
            return "File: \(url)\n\nError: \(error)"
        }
    }
}

struct ProfileScanner {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ProfileScanner.self)
    )
    
    private let directory: URL
    
    init(directory: URL) {
        self.directory = directory
    }
    
    func findBasebandLoggingProfile() throws -> ProfileStubData? {
        // First try to find the profile stub by its exact name
        if let profile = try findProfileByFilename() {
            Self.logger.debug("Found baseband logging profile by filename: \(profile)")
            return profile
        }
        
        // If not found, iterate through all installed profiles, maybe the profile UUID has changed
        if let profile = try findProfileByIterating() {
            Self.logger.debug("Found baseband logging profile by iteration: \(profile)")
            return profile
        }
        
        // No matching profile found
        Self.logger.debug("Unable to find baseband logging profile")
        return nil
    }
    
    private func findProfileByFilename() throws -> ProfileStubData? {
        // The stub file of the baseband logging profile usually has this specific name
        let file = directory.appendingPathComponent("profile-4c14f9f4fce08bcdf328217d5534a49ac4b5847b440bfd65d2fde1e9123002fd.stub", isDirectory: false)
        
        // Try to see if it exists
        guard FileManager.default.fileExists(atPath: file.path) else {
            return nil
        }
        
        // If so, read it
        return try readStubFile(url: file)
    }
    
    private func findProfileByIterating() throws -> ProfileStubData? {
        // Iterate through all profile stub files to find the baseband logging profile as Apple might change its UUID.
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey])
        
        for file in files {
            // Only read profile stub files
            guard file.lastPathComponent.hasPrefix("profile-") && file.lastPathComponent.hasSuffix(".stub") else {
                continue
            }
            
            if let profile = try readStubFile(url: file) {
                return profile
            }
        }
        
        return nil
    }
    
    func readStubFile(url: URL) throws -> ProfileStubData? {
        do {
            let data = try Data(contentsOf: url)
            let profile = try PropertyListDecoder().decode(ProfileStubData.self, from: data)
            
            guard profile.payloadIdentifier == "com.apple.basebandlogging" else {
                return nil
            }
            
            return profile
        } catch {
            throw ProfileScannerError.CantReadStub(url, error)
        }
    }
    
}
