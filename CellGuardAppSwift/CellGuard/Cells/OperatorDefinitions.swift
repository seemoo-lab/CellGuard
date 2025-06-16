//
//  OperatorDefinitions.swift
//  CellGuard
//
//  Created by Lukas Arnold on 15.06.23.
//

import CSV
import Foundation
import OSLog
import SwiftGzip

private let wikipediaUrlPrefix = "https://en.wikipedia.org"

private func trimCountryName(name: String) -> String {
    if name.hasSuffix(", Federated States of") {
        return name.split(separator: ",").first?.trimmingCharacters(in: .whitespaces) ?? name
    }

    if name.hasSuffix(")") {
        return name.split(separator: "(").first?.trimmingCharacters(in: .whitespaces) ?? name
    }

    return name
}

struct NetworkCountry: Identifiable, Decodable {
    let mcc: String
    let name: String
    let iso: String
    let mncUrls: String?

    // A MCC can be assigned to multiple countries / territories
    var id: String { self.mcc + "_" + self.name }

    enum CodingKeys: String, CodingKey {
        case mcc
        case name
        case iso
        case mncUrls = "mnc_urls"
    }

    var wikipediaMncUrls: URL? {
        guard let mncUrls = mncUrls else {
            return nil
        }

        return URL(string: wikipediaUrlPrefix + mncUrls)
    }

    var shortName: String {
        trimCountryName(name: self.name)
    }
}

enum NetworkOperatorStatus: Int, Decodable {
    case notOperational = -1
    case unknown = 0
    case operational = 1

    func humanString() -> String {
        switch self {
        case .notOperational:
            return "Not operational"
        case .unknown:
            return "Unknown"
        case .operational:
            return "Operational"
        }
    }
}

struct NetworkOperator: Decodable, Identifiable {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: NetworkOperator.self)
    )

    let mcc: String
    let mnc: String
    let status: NetworkOperatorStatus

    let brandName: String?
    let brandUrl: String?

    let operatorName: String?
    let operatorUrl: String?

    let countryName: String
    // May be empty (international networks) or contain multiple ISOs separated with '/'
    let isoString: String?
    // If there are multiple ISOs defined, then this field contains more for information about them separated with '##'
    let countryInclude: String?
    let countryUrl: String

    var id: String { self.mcc + "-" + self.mnc }

    enum CodingKeys: String, CodingKey {
        case mcc
        case mnc
        case status
        case brandName = "brand"
        case brandUrl = "brand_url"
        case operatorName = "operator"
        case operatorUrl = "operator_url"
        case countryName = "country_name"
        case isoString = "iso"
        case countryInclude = "country_include"
        case countryUrl = "country_url"
    }

    var combinedName: String? {
        brandName ?? operatorName
    }

    var wikipediaBrandUrl: URL? {
        guard let brandUrl = brandUrl else {
            return nil
        }

        return URL(string: wikipediaUrlPrefix + brandUrl)
    }

    var wikipediaOperatorUrl: URL? {
        guard let operatorUrl = operatorUrl else {
            return nil
        }

        return URL(string: wikipediaUrlPrefix + operatorUrl)
    }

    var wikipediaCountryUrl: URL? {
        return URL(string: wikipediaUrlPrefix + countryUrl)
    }

    var isoList: [String] {
        isoString?.split(separator: "/").map(String.init) ?? []
    }

    var countryIncludeList: [(name: String, iso: String)] {
        var list: [(String, String)] = []

        for countryString in countryInclude?.components(separatedBy: "##") ?? [] {
            let split = countryString.components(separatedBy: " – ")
            if split.count < 2 {
                Self.logger.warning("Cannot process included country string \(countryString)")
                continue
            }
            list.append((split[0], split[1]))
        }

        return list
    }

    var shortCountryName: String {
        trimCountryName(name: self.countryName)
    }

}

enum OperatorDefinitionsError: Error {
    case invalidURL(String)
    case cantConvertToString(String)
}

struct OperatorDefinitions {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: OperatorDefinitions.self)
    )

    private static func csvReader(forResource resource: String) throws -> CSVReader {
        // Get the URL of the countries.csv.gz file in the bundle
        guard let url = Bundle.main.url(forResource: resource, withExtension: "gz") else {
            throw OperatorDefinitionsError.invalidURL(resource)
        }

        // Gunzip the compressed files
        let decompressor = GzipDecompressor()
        let compressedData = try Data(contentsOf: url)
        let data = try decompressor.unzip(data: compressedData)

        // Convert to string
        guard let str = String(data: data, encoding: .utf8) else {
            throw OperatorDefinitionsError.cantConvertToString(resource)
        }

        // Create a CSV reader for the string
        return try CSVReader(string: str, hasHeaderRow: true)
    }

    static let shared: OperatorDefinitions = {
        var countries: [NetworkCountry] = []
        var operators: [NetworkOperator] = []

        // Convert the files contents into Swift objects
        do {
            let decoder = CSVRowDecoder()

            let readerCountries = try csvReader(forResource: "countries.csv")
            while readerCountries.next() != nil {
                countries.append(try decoder.decode(NetworkCountry.self, from: readerCountries))
            }

            let readerOperators = try csvReader(forResource: "operators.csv")
            while readerOperators.next() != nil {
                operators.append(try decoder.decode(NetworkOperator.self, from: readerOperators))
            }
        } catch {
            logger.warning("Failed to decode the CSV files countries.csv.gz & operators.csv.gz: \(error)")
        }

        return OperatorDefinitions(countries: countries, operators: operators)
    }()

    // The number of preceding zeros is important to distinguish MCCs
    let countriesByMcc: [String: [NetworkCountry]]
    let countriesByIso: [String: [NetworkCountry]]
    let networks: [Int: [Int: [NetworkOperator]]]

    private init(countries: [NetworkCountry], operators: [NetworkOperator]) {
        // We map the list of operators to a dictionary to allow for simple retrieval of operators by MCC & MNC
        self.networks = Dictionary(grouping: operators) { Int($0.mcc) ?? -1 }
            .mapValues { Dictionary(grouping: $0) { Int($0.mnc) ?? -1 } }
        self.countriesByMcc = Dictionary(grouping: countries) { $0.mcc }
        self.countriesByIso = Dictionary(grouping: countries) { $0.iso }
    }

    func translate(country: Int32, network: Int32) -> NetworkOperator? {
        return networks[Int(country)]?[Int(network)]?.first
    }

}
