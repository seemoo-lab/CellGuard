//
//  QMIDefinitions.swift
//  CellGuard
//
//  Created by Lukas Arnold on 08.06.23.
//

import Foundation
import OSLog
import SwiftGzip

struct QMIDefinitions {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: QMIDefinitions.self)
    )

    static let shared: QMIDefinitions = {
        // Get the URL of the qmi-definitions.json file in the bundle
        guard let url = Bundle.main.url(forResource: "qmi-definitions.json", withExtension: "gz") else {
            logger.warning("Failed to get the URL for qmi-definitions.json.gz")
            return QMIDefinitions(serviceList: [])
        }

        // Convert the file's content into Swift objects
        do {
            // Gunzip the compressed file
            let decompressor = GzipDecompressor()
            let compressedData = try Data(contentsOf: url)
            let data = try decompressor.unzip(data: compressedData)

            // https://www.avanderlee.com/swift/json-parsing-decoding/
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let services = try decoder.decode([QMIDefinitionService].self, from: data)

            return QMIDefinitions(serviceList: services)
        } catch {
            logger.warning("Failed to decode the JSON file qmi-definitions.json.gz: \(error)")
            return QMIDefinitions(serviceList: [])
        }
    }()

    let services: [UInt8: QMIDefinitionService]

    private init(serviceList: [QMIDefinitionService]) {
        // We map the list of services to a dictionary to allow for simple retrieval of service details
        self.services = Dictionary(uniqueKeysWithValues: serviceList.map { ($0.identifier, $0) })
    }

}

struct QMIDefinitionService: Decodable, Identifiable {

    let identifier: UInt8
    let shortName: String
    let longName: String
    let messages: [UInt16: QMIDefinitionElement]
    let indications: [UInt16: QMIDefinitionElement]

    enum CodingKeys: CodingKey {
        case identifier
        case shortName
        case longName
        case messages
        case indications
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.identifier = try container.decode(UInt8.self, forKey: .identifier)
        self.shortName = try container.decode(String.self, forKey: .shortName)
        self.longName = try container.decode(String.self, forKey: .longName)

        // We map the list to a dictionary to allow for simple retrieval of message and indications by their id
        self.messages = QMIDefinitionElement.dictionary(try container.decode([QMIDefinitionElement].self, forKey: .messages))
        self.indications = QMIDefinitionElement.dictionary(try container.decode([QMIDefinitionElement].self, forKey: .indications))
    }

    var id: UInt8 { self.identifier }

    var name: String { self.longName }

}

struct QMIDefinitionElement: CommonDefinitionElement {

    let identifier: UInt16
    let name: String

}
