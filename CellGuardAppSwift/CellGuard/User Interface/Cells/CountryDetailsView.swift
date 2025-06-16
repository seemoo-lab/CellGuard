//
//  CountryDetails.swift
//  CellGuard
//
//  Created by Lukas Arnold on 02.04.25.
//

import SwiftUI

struct CountryDetailsView: View {
    let netOperator: NetworkOperator

    var body: some View {
        List {
            Section {
                CellDetailsRow("Name", netOperator.countryName)
                CellDetailsRow("ISO", netOperator.isoString ?? "-")
                CellDetailsRow("MCC", netOperator.mcc)

                if let wikipediaUrl = netOperator.wikipediaCountryUrl {
                    Link(destination: wikipediaUrl) {
                        KeyValueListRow(key: "View on Wikipedia") {
                            wikipediaIcon
                        }
                    }
                }
            }

            IncludeCountrySection(includeList: netOperator.countryIncludeList)

            SimilarMccSection(countries: OperatorDefinitions.shared.countriesByMcc[netOperator.mcc] ?? [])

            SimilarIsoSection(countries: OperatorDefinitions.shared.countriesByIso[netOperator.isoString ?? ""] ?? [])
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Country")
    }
}

private struct IncludeCountrySection: View {
    let includeList: [(name: String, iso: String)]

    var body: some View {
        if !includeList.isEmpty {
            Section(header: Text("Includes")) {
                ForEach(includeList, id: \.0) { include in
                    KeyValueListRow(key: include.name, value: include.iso)
                }
            }
        }
    }
}

private struct SimilarMccSection: View {
    let countries: [NetworkCountry]

    var body: some View {
        if countries.count > 1 {
            Section(header: Text("Similar Mobile Country Code")) {
                ForEach(countries) { country in
                    KeyValueListRow(key: country.name, value: country.iso)
                }
            }
        }
    }
}

private struct SimilarIsoSection: View {
    let countries: [NetworkCountry]

    var body: some View {
        if countries.count > 1 {
            Section(header: Text("Similar ISO Code")) {
                ForEach(countries) { country in
                    KeyValueListRow(key: country.name, value: country.mcc)
                }
            }
        }
    }
}

#Preview("DE") {
    NavigationView {
        CountryDetailsView(netOperator: OperatorDefinitions.shared.translate(country: 262, network: 01)!)
    }
}

#Preview("US") {
    NavigationView {
        CountryDetailsView(netOperator: OperatorDefinitions.shared.translate(country: 310, network: 04)!)
    }
}

#Preview("UK") {
    NavigationView {
        CountryDetailsView(netOperator: OperatorDefinitions.shared.translate(country: 234, network: 02)!)
    }
}

#Preview("GG") {
    NavigationView {
        CountryDetailsView(netOperator: OperatorDefinitions.shared.translate(country: 234, network: 03)!)
    }
}

#Preview("AU") {
    NavigationView {
        CountryDetailsView(netOperator: OperatorDefinitions.shared.translate(country: 505, network: 01)!)
    }
}

#Preview("BQ/CW/SX") {
    NavigationView {
        CountryDetailsView(netOperator: OperatorDefinitions.shared.translate(country: 362, network: 31)!)
    }
}

#Preview("BL/GF/GP/MF/MQ") {
    NavigationView {
        CountryDetailsView(netOperator: OperatorDefinitions.shared.translate(country: 340, network: 01)!)
    }
}

#Preview("IN") {
    NavigationView {
        CountryDetailsView(netOperator: OperatorDefinitions.shared.translate(country: 405, network: 813)!)
    }
}

#Preview("Test") {
    NavigationView {
        CountryDetailsView(netOperator: OperatorDefinitions.shared.translate(country: 001, network: 01)!)
    }
}

#Preview("Int") {
    NavigationView {
        CountryDetailsView(netOperator: OperatorDefinitions.shared.translate(country: 901, network: 10)!)
    }
}
