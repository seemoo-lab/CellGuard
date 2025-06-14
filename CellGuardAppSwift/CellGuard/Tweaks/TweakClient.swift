//
//  TweakClient.swift
//  CellGuard
//
//  Created by Lukas Arnold on 06.06.23.
//

import Foundation
import Network
import OSLog

enum TweakClientError: Error {
    case unexpectedHello(String)
    case authTokenNotInKeychain
    case tweakUnreachable
}

struct TweakHelloMessage: CustomStringConvertible {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: TweakHelloMessage.self)
    )

    let name: String
    let version: String
    let authToken: Bool

    var description: String {
        return "\(name) v\(version) [requiresAuthToken: \(authToken)]"
    }

    static func parse(_ content: Data) throws -> TweakHelloMessage? {
        guard let str = String(data: content, encoding: .utf8) else {
            Self.logger.info("Failed to decode hello message: \(content.base64EncodedString())")
            return nil
        }

        // Self.logger.debug("Parsing hello message: \(str)")

        guard str.hasPrefix("Hello CellGuard") else {
            Self.logger.info("Failed to parse hello message with wrong prefix: \(str)")
            return nil
        }

        let components = str.split(separator: ",")
        guard components.count >= 4 else {
            throw TweakClientError.unexpectedHello(str)
        }

        return TweakHelloMessage(
            name: String(components[1]),
            version: String(components[2]).trimmingCharacters(in: CharacterSet(arrayLiteral: "\"")),
            authToken: components[3].elementsEqual("true")
        )
    }
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
            Self.logger.info("Auth token not in keychain (Status = \(status))")
            return nil
        }

        guard status == errSecSuccess else {
            let res = SecCopyErrorMessageString(status, nil)
            Self.logger.warning("Error \(status) while fetching auth key from keychain: \(res) (Status = \(status))")
            return nil
        }

        guard let tokenData = item as? Data,
            let token = String(data: tokenData, encoding: .utf8)
        else {
            Self.logger.warning("Cannot extract token from keychain")
            return nil
        }

        Self.logger.debug("Tweak Auth Token: \(token)")
        return token

    }

    /// Connects to the tweak, fetches all cells, and converts them into a dictionary structure.
    func query(completion: @escaping (Result<Data, Error>) -> Void, ready: @escaping (TweakHelloMessage?) -> Void) {
        // Create a connection to localhost on the given port
        let nwPort = NWEndpoint.Port(integerLiteral: UInt16(port))
        let connection = NWConnection(host: "127.0.0.1", port: nwPort, using: NWParameters.tcp)

        let newlineChar = Data("\n".utf8)

        // Store the data sent over multiple messages
        var data = Data()
        var firstNewlineReceived = false

        func receiveNextMessage() {
            connection.receive(minimumIncompleteLength: 0, maximumLength: 10 * 1024) { content, _, complete, error in
                // Uncomment the following for debugging the network connection
                // Self.logger.trace("Received Message (\(self.port)): \(content?.debugDescription ?? "nil") - \(context.debugDescription) - \(complete) - \(context?.isFinal ?? false) - \(error)")

                if let error = error {
                    // We've got an error
                    completion(.failure(error))

                    // Close the connection after a successful query to deregister the handlers
                    // See: https://stackoverflow.com/a/63599285
                    connection.cancel()
                    return
                }

                if let content = content {
                    // Append message data to the cache
                    data.append(contentsOf: content)
                }

                if !firstNewlineReceived, let range = data.firstRange(of: newlineChar) {
                    // Handle complete message
                    do {
                        if let helloMsg = try TweakHelloMessage.parse(data.subdata(in: 0..<range.lowerBound)) {
                            // We're communicating with a tweak >= 1.1.0
                            Self.logger.info("Communicating with tweak \(helloMsg)")

                            // Clear the already received data
                            data.removeAll()

                            // Pass the hello message to the tweak client implementation
                            ready(helloMsg)

                            // Send auth token if required
                            if helloMsg.authToken {
                                guard let authToken = fetchAuthToken() else {
                                    throw TweakClientError.authTokenNotInKeychain
                                }
                                connection.send(content: (authToken + "\n").data(using: .utf8), completion: .contentProcessed(authTokenSent))
                            }
                        }
                    } catch {
                        // Something failed during the parsing of the hello message
                        completion(.failure(error))
                        connection.cancel()
                        return
                    }
                    firstNewlineReceived = true
                }

                // We'll wait for the next message (if not complete)
                if !complete {
                    receiveNextMessage()
                } else {
                    // If it's the last message, we'll call the callback
                    completion(.success(data))

                    // Close the connection after a successful query to deregister the handlers
                    // See: https://stackoverflow.com/a/63599285
                    Self.logger.info("Closing connection because context is final")
                    connection.cancel()
                }
            }
        }

        func authTokenSent(error: NWError?) {
            if let error = error {
                Self.logger.error("Failed to send auth token: \(error)")
            } else {
                Self.logger.info("Successfully sent auth token")
            }
        }

        // Print the connection state
        connection.stateUpdateHandler = { state in
            Self.logger.trace("Connection State (\(self.port)) : \(String(describing: state))")

            if state == .ready {
                ready(nil)
                receiveNextMessage()
            }

            // If the connection has been refused (because the tweak is not active), we'll close it.
            // Otherwise CellGuard accumulates multiple waiting connections.
            if state == .waiting(.posix(.ECONNREFUSED)) {
                connection.cancel()
                completion(Result.failure(TweakClientError.tweakUnreachable))
            }
        }

        // Open the connection
        connection.start(queue: self.queue)
    }

}
