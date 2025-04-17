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
        guard let url = Bundle.main.url(forResource: "ari-definitions.json", withExtension: "gz") else {
            logger.warning("Failed to get the URL for ari-definitions.json.gz")
            return ARIDefinitions(groupList: [])
        }

        // Convert the file's content into Swift objects
        do {
            // Gunzip the compressed file
            let data = try Data(contentsOf: url).gunzipped()

            // https://www.avanderlee.com/swift/json-parsing-decoding/
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let services = try decoder.decode([ARIDefinitionGroup].self, from: data)

            return ARIDefinitions(groupList: services)
        } catch {
            logger.warning("Failed to decode the JSON file ari-definitions.json.gz: \(error)")
            return ARIDefinitions(groupList: [])
        }
    }()

    let groups: [UInt8: ARIDefinitionGroup]

    private init(groupList: [ARIDefinitionGroup]) {
        // We map the list of groups to a dictionary to allow for simple retrieval of service details
        self.groups = Dictionary(uniqueKeysWithValues: groupList.map { ($0.identifier, $0) })
    }

}

struct ARIDefinitionGroup: Decodable, Identifiable {

    let identifier: UInt8
    let name: String
    // TOOD: Include Name, Type
    let types: [UInt16: ARIDefinitionType]

    private enum CodingKeys: CodingKey {
        case identifier
        case name
        case types
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.identifier = try container.decode(UInt8.self, forKey: .identifier)
        // We cut this prefix appended to all group names for clarity
        self.name = try container.decode(String.self, forKey: .name).replacingOccurrences(of: "_ARIMSGDEF_GROUP", with: "")

        // We map the list to a dictionary to allow for simple retrieval of types by their id
        self.types = ARIDefinitionType.dictionary(try container.decode([ARIDefinitionType].self, forKey: .types))
    }

    var id: UInt8 { self.identifier }

}

struct ARIDefinitionType: CommonDefinitionElement {

    let identifier: UInt16
    let name: String
    let tlvs: [UInt16: ARIDefinitionTLV]

    private enum CodingKeys: CodingKey {
        case identifier
        case name
        case tlvs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.identifier = try container.decode(UInt16.self, forKey: .identifier)
        self.name = try container.decode(String.self, forKey: .name)

        // We map the TLV list to a dictionary to allow for simple retrieval of TLVs by their id
        self.tlvs = ARIDefinitionTLV.dictionary(try container.decode([ARIDefinitionTLV].self, forKey: .tlvs))
    }

}

struct ARIDefinitionTLV: CommonDefinitionElement {

    let identifier: UInt16
    let name: String
    let codecLength: UInt16
    let codecName: String

}
