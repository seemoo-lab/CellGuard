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

protocol NetworkCountryAttributes {
    var mcc: String { get }
    var countryName: String { get }
    // May be empty (international networks) or contain multiple ISOs separated with '/'
    var isoString: String? { get }
    // If there are multiple ISOs defined, then this field contains more for information about them separated with '##'
    var countryInclude: String? { get }
    var countryUrl: String? { get }
}

extension NetworkCountryAttributes {

    var shortCountryName: String {
        if countryName.hasSuffix(", Federated States of") {
            return countryName.split(separator: ",").first?.trimmingCharacters(in: .whitespaces) ?? countryName
        }

        if countryName.hasSuffix(")") {
            return countryName.split(separator: "(").first?.trimmingCharacters(in: .whitespaces) ?? countryName
        }

        return countryName
    }

    var isoList: [String] {
        isoString?.split(separator: "/").map(String.init) ?? []
    }

    var countryIncludeList: [(name: String, iso: String)] {
        var list: [(String, String)] = []

        for countryString in countryInclude?.components(separatedBy: "##") ?? [] {
            let split = countryString.components(separatedBy: " – ")
            if split.count < 2 {
                NetworkOperator.logger.warning("Cannot process included country string \(countryString)")
                continue
            }
            list.append((split[0], split[1]))
        }

        return list
    }

    var wikipediaCountryUrl: URL? {
        guard let countryUrl = countryUrl else {
            return nil
        }
        return URL(string: wikipediaUrlPrefix + countryUrl)
    }

    var similarMcc: [NetworkCountry] {
        OperatorDefinitions.shared.countriesByMcc[mcc]?
            .filter { $0.countryName != countryName } ?? []
    }

    var similarIso: [NetworkCountry] {
        guard let isoString = isoString else {
            return []
        }
        return OperatorDefinitions.shared.countriesByIso[isoString]?
            .filter { $0.mcc != mcc } ?? []
    }
}

struct NetworkCountry: NetworkCountryAttributes, Identifiable, Decodable {
    let mcc: String
    let countryName: String
    let isoString: String?
    let countryInclude: String?
    let countryUrl: String?

    // A MCC can be assigned to multiple countries / territories
    var id: String { self.mcc + "-" + self.countryName }

    enum CodingKeys: String, CodingKey {
        case mcc
        case countryName = "country_name"
        case isoString = "iso"
        case countryInclude = "country_include"
        case countryUrl = "country_url"
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

struct NetworkOperator: NetworkCountryAttributes, Decodable, Identifiable {

    static let logger = Logger(
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
    let isoString: String?
    let countryInclude: String?
    let countryUrl: String?

    var id: String { self.mcc + "-" + self.mnc + "-" + self.countryName + "-" + (self.brandName ?? "") + "-" + (self.operatorName ?? "") }

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
        self.countriesByIso = Dictionary(grouping: countries) { $0.isoString ?? "" }
    }

    private func primaryCountryByIso(_ iso: String, _ results: [NetworkCountry]) -> (primary: NetworkCountry?, secondary: [NetworkCountry]) {
        guard let primary = results.first(where: { $0.isoString == iso }) else {
            Self.logger.warning("Could not find primary country for \(iso) in \(results)")
            return (results[0], Array(results.suffix(from: 1)))
        }
        let secondary = results.filter { $0.isoString != iso }

        return (primary, secondary)
    }

    private func primaryCountrySummary(_ name: String, _ results: [NetworkCountry]) -> (primary: NetworkCountry?, secondary: [NetworkCountry]) {
        let summaryCountry = NetworkCountry(
            // The MCC is the same for all countries, thus we can just use the one of the first country
            mcc: results[0].mcc,
            // We define the name of the "virtual" summary country
            countryName: name,
            // We join the ISOs
            isoString: results.compactMap { $0.isoString }.joined(separator: "/"),
            countryInclude: nil,
            countryUrl: nil
        )
        return (summaryCountry, results)
    }

    func translate(country: Int32) -> (primary: NetworkCountry?, secondary: [NetworkCountry]) {
        // Invalid MCC
        if country > 999 {
            Self.logger.warning("Invalid MCC for country lookup: \(country)")
            return (nil, [])
        }

        // Every MCC is 3 digits long
        let results = countriesByMcc[String(format: "%03d", country)]
        guard let results = results, !results.isEmpty else {
            return (nil, [])
        }

        if results.count == 1 {
            return (results[0], [])
        }

        // Now, we've arrived at the special cases that there is more than one country defined for a given MCC.
        switch country {
        case 234:
            return primaryCountryByIso("GB", results)
        case 310...316:
            return primaryCountryByIso("US", results)
        case 338:
            return primaryCountrySummary("West Indies", results)
        case 425:
            return primaryCountryByIso("IL", results)
        case 505:
            // Australia, Cocos Islands, and Christmas Island are listed as one, hence the wired ISO code
            return primaryCountryByIso("AU/CC/CX", results)
        default:
            // If this warning appears, you might have to add new special case handlers for the given MCC
            Self.logger.warning("Unhandled multi result case for MCC \(country): \(results)")
            return (results[0], Array(results.suffix(from: 1)))
        }
    }

    func translate(country: Int32, network: Int32) -> [NetworkOperator] {
        return networks[Int(country)]?[Int(network)] ?? []
    }

}

extension Array where Iterator.Element == NetworkOperator {

    var firstCombinedName: String? {
        first(where: { $0.combinedName != nil })?.combinedName
    }

    var firstIsoString: String? {
        first(where: { $0.isoString != nil })?.isoString
    }

    var combinedIsoList: [String] {
        compactMap { $0.isoList }.reduce([], +)
    }

    var combinedIsoString: String? {
        combinedIsoList.joined(separator: "/")
    }

}
