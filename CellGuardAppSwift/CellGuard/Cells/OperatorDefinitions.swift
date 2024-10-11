//
//  OperatorDefinitions.swift
//  CellGuard
//
//  Created by Lukas Arnold on 15.06.23.
//

import Foundation
import OSLog

struct OperatorDefinitions {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: OperatorDefinitions.self)
    )
    
    static let shared: OperatorDefinitions = {
        // Get the URL of the qmi-definitions.json file in the bundle
        guard let url = Bundle.main.url(forResource: "operator-definitions.json", withExtension: "gz") else {
            logger.warning("Failed to get the URL for operator-definitions.json.gz")
            return OperatorDefinitions(operators: [])
        }
        
        // Convert the file's content into Swift objects
        do {
            // Gunzip the compressed file
            let data = try Data(contentsOf: url).gunzipped()
            
            // https://www.avanderlee.com/swift/json-parsing-decoding/
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let operators = try decoder.decode([NetworkOperator].self, from: data)
            
            return OperatorDefinitions(operators: operators)
        } catch {
            logger.warning("Failed to decode the JSON file operator-definitions.json.gz: \(error)")
            return OperatorDefinitions(operators: [])
        }
    }()
    
    let countries: [Int: [Int: [NetworkOperator]]]
    
    private init(operators: [NetworkOperator]) {
        // We map the list of operators to a dictionary to allow for simple retrieval of operators by MCC & MNC
        self.countries = Dictionary(grouping: operators) { $0.mcc }
            .mapValues { Dictionary(grouping: $0) { $0.mnc } }
    }
    
    func translate(country: Int32, iso: Bool = false) -> String? {
        let firstNetworkOperator = countries[Int(country)]?.first?.value.first
        return iso ? firstNetworkOperator?.countryIso : firstNetworkOperator?.countryName
    }
    
    func translate(country: Int32, network: Int32, iso: Bool = false) -> (String?, String?) {
        if let networkOperator = networkOperator(country: country, network: network) {
            return (iso ? networkOperator.countryIso: networkOperator.countryName, networkOperator.networkName)
        }
        
        // Fallback to a random network operator to return at least the country name
        return (translate(country: country, iso: iso), nil)
    }
    
    private func networkOperator(country: Int32, network: Int32) -> NetworkOperator? {
        guard let countryDict = countries[Int(country)] else {
            return nil
        }
        
        guard let operators = countryDict[Int(network)] else {
            return nil
        }
        
        if operators.isEmpty {
            return nil
        }
        
        // We prefer entry with a given network name, especially if there are multiple entries for with the same MCC & MNC
        if let networkOperator = operators.filter({ $0.networkName != nil }).first {
            return networkOperator
        }
        
        // Fallback to the first network operator, if there's none with a name
        return operators.first
    }
    
}

struct NetworkOperator: Decodable, Identifiable {
    let mcc: Int
    let mnc: Int
    let countryIso: String
    let countryName: String
    let countryCode: Int?
    let networkName: String?
    
    var id: Int { self.mnc }
}
