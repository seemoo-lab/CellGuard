//
//  StudyClient.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.06.24.
//

import Foundation
import OSLog

enum StudyClientError: Error {
    case uploadErrorLocal(Error)
    case uploadErrorExternal(URLResponse?)
}

// The client for the backend
struct StudyClient {
    
    internal static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: StudyClient.self)
    )
    
    internal let persistence = PersistenceController()
    internal let jsonEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()
    
    internal func upload(jsonData: Data, url: URL, description: String) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(), any Error>) in
            URLSession.shared.uploadTask(with: request, from: jsonData) { data, response, error in
                if let error = error {
                    Self.logger.debug("Error while \(description): \(error)")
                    continuation.resume(throwing: StudyClientError.uploadErrorLocal(error))
                    return
                }
                guard let response = response as? HTTPURLResponse, response.statusCode == 201 else {
                    Self.logger.debug("Server error while \(description): \(response)")
                    continuation.resume(throwing: StudyClientError.uploadErrorExternal(response))
                    return
                }
                
                Self.logger.debug("Successfully \(description): \(response)")
                continuation.resume()
                return
            }
        }
    }
    
}
