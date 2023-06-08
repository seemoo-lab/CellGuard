//
//  QMIDefinitions.swift
//  CellGuard
//
//  Created by Lukas Arnold on 08.06.23.
//

import Foundation
import OSLog

struct QMIDefinitions {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: QMIDefinitions.self)
    )
    
    static let shared: QMIDefinitions = {
        // Get the URL of the qmi-definitions.json file in the bundle
        guard let url = Bundle.main.url(forResource: "qmi-definitions", withExtension: "json") else {
            logger.warning("Failed to get the URL for qmi-definitions.json")
            return QMIDefinitions(serviceList: [])
        }
        
        // Convert the file's content into Swift objects
        do {
            // https://www.avanderlee.com/swift/json-parsing-decoding/
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let services = try decoder.decode([QMIDefintionService].self, from: try Data(contentsOf: url))
            
            return QMIDefinitions(serviceList: services)
        } catch {
            logger.warning("Failed to decode the JSON file qmi-definitions.json: \(error)")
            return QMIDefinitions(serviceList: [])
        }
    }()
    
    let services: [UInt8: QMIDefintionService]
    
    private init(serviceList: [QMIDefintionService]) {
        self.services = Dictionary(uniqueKeysWithValues: serviceList.map { ($0.identifier, $0) })
    }
    
}

struct QMIDefintionService: Decodable {
    
    let identifier: UInt8
    let shortName: String
    let longName: String
    let messages: [UInt16: CommonDefinitionElement]
    let indications: [UInt16: CommonDefinitionElement]
    
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
        
        self.messages = CommonDefinitionElement.dictionary(try container.decode([CommonDefinitionElement].self, forKey: .messages))
        self.indications = CommonDefinitionElement.dictionary(try container.decode([CommonDefinitionElement].self, forKey: .indications))
    }
    
}
