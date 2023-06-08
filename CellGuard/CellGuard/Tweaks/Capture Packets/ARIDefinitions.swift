//
//  ARIDefinitions.swift
//  CellGuard
//
//  Created by Lukas Arnold on 08.06.23.
//

import Foundation
import OSLog

struct ARIDefinitions {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ARIDefinitions.self)
    )
    
    static let shared: ARIDefinitions = {
        // Get the URL of the qmi-definitions.json file in the bundle
        guard let url = Bundle.main.url(forResource: "ari-definitions", withExtension: "json") else {
            logger.warning("Failed to get the URL for ari-definitions.json")
            return ARIDefinitions(groupList: [])
        }
        
        // Convert the file's content into Swift objects
        do {
            // https://www.avanderlee.com/swift/json-parsing-decoding/
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let services = try decoder.decode([ARIDefinitionGroup].self, from: try Data(contentsOf: url))
            
            return ARIDefinitions(groupList: services)
        } catch {
            logger.warning("Failed to decode the JSON file qmi-definitions.json: \(error)")
            return ARIDefinitions(groupList: [])
        }
    }()
    
    let groups: [UInt8: ARIDefinitionGroup]
    
    private init(groupList: [ARIDefinitionGroup]) {
        self.groups = Dictionary(uniqueKeysWithValues: groupList.map { ($0.identifier, $0) })
    }
    
}

struct ARIDefinitionGroup: Decodable {
    
    let identifier: UInt8
    let name: String
    let types: [UInt16: CommonDefinitionElement]
    
    enum CodingKeys: CodingKey {
        case identifier
        case name
        case types
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.identifier = try container.decode(UInt8.self, forKey: .identifier)
        self.name = try container.decode(String.self, forKey: .name)
        
        self.types = CommonDefinitionElement.dictionary(try container.decode([CommonDefinitionElement].self, forKey: .types))
    }
    
}
