//
//  TweakClient.swift
//  CellGuard
//
//  Created by Lukas Arnold on 06.06.23.
//

import Foundation
import Network
import OSLog

enum AuthTokenError: Error {
    case gotNothing
}

struct TweakClient {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: TweakClient.self)
    )

    /// The port of the tweak
    let port: Int

    /// The queue used for processing incoming messages
    let queue: DispatchQueue

    func fetchAuthToken() -> String? {
        // https://developer.apple.com/documentation/security/searching-for-keychain-items
        let service = "capture-packets-token"
        let searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(searchQuery as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            Self.logger.info("Auth key not in keychain")
            return nil
        }

        guard status == errSecSuccess else {
            let res = SecCopyErrorMessageString(status, nil)
            Self.logger.warning("Error \(status) while fetching auth key from keychain: \(res)")
            return nil
        }

        guard let tokenData = item as? Data,
            let token = String(data: tokenData, encoding: .utf8)
        else {
            Self.logger.warning("Cannot extract token from keychain")
            return nil
        }
        return token

    }

    /// Connects to the tweak, fetches all cells, and converts them into a dictionary structure.
    func query(completion: @escaping (Result<Data, Error>) -> Void, ready: @escaping () -> Void) {
        guard let authToken = fetchAuthToken() else {
            completion(.failure(AuthTokenError.gotNothing))
            return
        }
        Self.logger.info("Tweak Auth Key: \(authToken)")

        // Create a connection to localhost on the given port
        let nwPort = NWEndpoint.Port(integerLiteral: UInt16(port))
        let connection = NWConnection(host: "127.0.0.1", port: nwPort, using: NWParameters.tcp)

        // Store the data sent over multiple messages
        var data = Data()

        func receiveNextMessage() {
            connection.receiveMessage { content, context, complete, error in
                Self.logger.trace("Received Message (\(self.port)): \(content?.debugDescription ?? "nil") - \(context.debugDescription) - \(complete) - \(context?.isFinal ?? false) - \(error)")

                if let error = error {
                    // We've got an error
                    completion(.failure(error))

                    // Close the connection after a successful query to deregister the handlers
                    // See: https://stackoverflow.com/a/63599285
                    connection.cancel()
                    return
                }

                if let content = content {
                    // We've got a full response with data and we'll append it to the cache
                    data.append(contentsOf: content)
                }

                if context?.isFinal ?? false {
                    // If it's the last message, we'll call the callback
                    completion(.success(data))

                    // Close the connection after a successful query to deregister the handlers
                    // See: https://stackoverflow.com/a/63599285
                    connection.cancel()
                } else {
                    // If it's not the last message, we'll wait for the next one
                    receiveNextMessage()
                }
            }
        }

        // Print the connection state
        connection.stateUpdateHandler = { state in
            Self.logger.trace("Connection State (\(self.port)) : \(String(describing: state))")

            if state == .ready {
                ready()
                receiveNextMessage()
            }

            // If the connection has been refused (because the tweak is not active), we'll close it.
            // Otherwise CellGuard accumulates multiple waiting connections.
            if state == .waiting(.posix(.ECONNREFUSED)) {
                connection.cancel()
            }
        }

        // Open the connection
        connection.start(queue: self.queue)
    }

}
