//
//  CountryDetails.swift
//  CellGuard
//
//  Created by Lukas Arnold on 02.04.25.
//

import SwiftUI
import NavigationBackport

struct CountryDetailsNavigation<C: NetworkCountryAttributes>: Hashable {
    let country: C
    let secondary: [NetworkCountry]?

    init(country: C, secondary: [NetworkCountry]? = nil) {
        self.country = country
        self.secondary = secondary
    }
}

struct CountryDetailsView<C: NetworkCountryAttributes>: View {
    let country: C
    let secondary: [NetworkCountry]?

    init(country: C, secondary: [NetworkCountry]? = nil) {
        self.country = country
        self.secondary = secondary
    }

    var body: some View {
        List {
            Section {
                CellDetailsRow("Name", country.countryName)
                CellDetailsRow("ISO", country.isoString ?? "-")
                CellDetailsRow("MCC", country.mcc)

                if let wikipediaUrl = country.wikipediaCountryUrl {
                    Link(destination: wikipediaUrl) {
                        KeyValueListRow(key: "View on Wikipedia") {
                            wikipediaIcon
                        }
                    }
                }
            }

            IncludeCountrySection(includeList: country.countryIncludeList)

            SimilarMccSection(countries: secondary ?? country.similarMcc)

            SimilarIsoSection(countries: country.similarIso)
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
        if countries.count > 0 {
            Section(header: Text("Similar Mobile Country Code")) {
                ForEach(countries) { country in
                    KeyValueListRow(key: country.countryName, value: country.isoString ?? "-")
                }
            }
        }
    }
}

private struct SimilarIsoSection: View {
    let countries: [NetworkCountry]

    var body: some View {
        if countries.count > 0 {
            Section(header: Text("Similar ISO Code")) {
                ForEach(countries) { country in
                    KeyValueListRow(key: country.countryName, value: country.mcc)
                }
            }
        }
    }
}

#Preview("DE") {
    NBNavigationStack {
        CountryDetailsView(country: OperatorDefinitions.shared.translate(country: 262, network: 01).first!)
    }
}

#Preview("US") {
    NBNavigationStack {
        CountryDetailsView(country: OperatorDefinitions.shared.translate(country: 310, network: 04).first!)
    }
}

#Preview("UK") {
    NBNavigationStack {
        CountryDetailsView(country: OperatorDefinitions.shared.translate(country: 234, network: 02).first!)
    }
}

#Preview("GG") {
    NBNavigationStack {
        CountryDetailsView(country: OperatorDefinitions.shared.translate(country: 234, network: 03).first!)
    }
}

#Preview("AU") {
    NBNavigationStack {
        CountryDetailsView(country: OperatorDefinitions.shared.translate(country: 505, network: 01).first!)
    }
}

#Preview("BQ/CW/SX") {
    NBNavigationStack {
        CountryDetailsView(country: OperatorDefinitions.shared.translate(country: 362, network: 31).first!)
    }
}

#Preview("BL/GF/GP/MF/MQ") {
    NBNavigationStack {
        CountryDetailsView(country: OperatorDefinitions.shared.translate(country: 340, network: 01).first!)
    }
}

#Preview("IN") {
    NBNavigationStack {
        CountryDetailsView(country: OperatorDefinitions.shared.translate(country: 405, network: 813).first!)
    }
}

#Preview("Test") {
    NBNavigationStack {
        CountryDetailsView(country: OperatorDefinitions.shared.translate(country: 001, network: 01).first!)
    }
}

#Preview("Int") {
    NBNavigationStack {
        CountryDetailsView(country: OperatorDefinitions.shared.translate(country: 901, network: 10).first!)
    }
}
