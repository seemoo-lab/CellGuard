//
//  CellCountryNetworkSection.swift
//  CellGuard
//
//  Created by Lukas Arnold on 02.04.25.
//

import SwiftUI
import NavigationBackport

struct CellCountryNetworkSection: View {

    let country: Int32
    let network: Int32
    let netOperators: [NetworkOperator]
    let netCountries: (primary: NetworkCountry?, secondary: [NetworkCountry])?
    let techFormatter: CellTechnologyFormatter

    init(country: Int32, network: Int32, techFormatter: CellTechnologyFormatter) {
        self.country = country
        self.network = network
        self.techFormatter = techFormatter

        // Get country & network information based on the operator (MCC + MNC)
        self.netOperators = OperatorDefinitions.shared.translate(country: country, network: network)
        // Get country information based on network (MCC)
        self.netCountries = OperatorDefinitions.shared.translate(country: country)
    }

    var body: some View {
        Section(header: Text("Country & Network")) {
            CellDetailsRow(techFormatter.country(), country)
            if let netOperator = netOperators.first, netOperators.count == 1 {
                // If there's exactly one network, we show its country
                ListNavigationLink(value: CountryDetailsNavigation(country: netOperator)) {
                    CellDetailsRow("Country", netOperator.shortCountryName)
                }
            } else if let (primary, secondary) = netCountries, let primary = primary {
                // If there is no network or there are multiple ones, we use the generic country
                ListNavigationLink(value: CountryDetailsNavigation(country: primary, secondary: secondary)) {
                    // Show "+ X" if multiple countries refer to a MCC
                    CellDetailsRow("Country", secondary.isEmpty ? primary.shortCountryName : "\(primary.shortCountryName) + \(secondary.count)" )
                }
            }
            CellDetailsRow(techFormatter.network(), formatMNC(network))
            if let netOperator = netOperators.first, let combinedName = netOperator.combinedName {
                ListNavigationLink(value: netOperators) {
                    CellDetailsRow("Network", netOperators.count >= 2 ? "\(combinedName) + \(netOperators.count - 1)" : combinedName)
                }
            }
        }
    }
}

struct SingleCellCountryNetworkNav: Hashable {
    let country: Int32
    let network: Int32
    let technology: ALSTechnology
}

struct SingleCellCountryNetworkView: View {
    let nav: SingleCellCountryNetworkNav

    var body: some View {
        List {
            CellCountryNetworkSection(
                country: nav.country,
                network: nav.network,
                techFormatter: CellTechnologyFormatter(technology: nav.technology)
            )
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Operator")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PreviewShellView<T: View>: View {

    let view: T

    init(@ViewBuilder _ builder: () -> T) {
        self.view = builder()
    }

    var body: some View {
        NBNavigationStack {
            List {
                view
            }
            .cgNavigationDestinations(.operators)
        }
    }

}

// Here are some test cases for country-only data (because there exists no operator with MNC 999).
// Other test cases for countries (from specific network operators) are in the CountryDetailsView.swift.
// Run the generate_operators.py script and use the "duplicate entries" as special test cases.
// You can also build the app using debug mode and use the operator lookup (three dots -> operators) instead of the previews.
#Preview("French Antilles") {
    PreviewShellView {
        CellCountryNetworkSection(
            country: 340,
            network: 999,
            techFormatter: CellTechnologyFormatter(technology: .LTE)
        )
    }
}

#Preview("Former Netherlands Antilles") {
    PreviewShellView {
        CellCountryNetworkSection(
            country: 362,
            network: 999,
            techFormatter: CellTechnologyFormatter(technology: .LTE)
        )
    }
}

#Preview("French Indian Ocean Territories") {
    PreviewShellView {
        CellCountryNetworkSection(
            country: 647,
            network: 999,
            techFormatter: CellTechnologyFormatter(technology: .LTE)
        )
    }
}

#Preview("US") {
    PreviewShellView {
        CellCountryNetworkSection(
            country: 310,
            network: 999,
            techFormatter: CellTechnologyFormatter(technology: .LTE)
        )
    }
}

#Preview("US") {
    PreviewShellView {
        CellCountryNetworkSection(
            country: 310,
            network: 999,
            techFormatter: CellTechnologyFormatter(technology: .LTE)
        )
    }
}
