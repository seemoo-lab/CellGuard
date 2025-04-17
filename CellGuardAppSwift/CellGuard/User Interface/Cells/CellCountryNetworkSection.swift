//
//  CellCountryNetworkSection.swift
//  CellGuard
//
//  Created by Lukas Arnold on 02.04.25.
//

import SwiftUI

struct CellCountryNetworkSection: View {

    let country: Int32
    let network: Int32
    let netCountry: NetworkCountry?
    let netOperator: NetworkOperator?
    let techFormatter: CellTechnologyFormatter

    init(country: Int32, network: Int32, techFormatter: CellTechnologyFormatter) {
        self.country = country
        self.network = network
        self.netCountry = OperatorDefinitions.shared.translate(country: country)
        self.netOperator = OperatorDefinitions.shared.translate(country: country, network: network)
        self.techFormatter = techFormatter
    }

    var body: some View {
        Section(header: Text("Country & Network")) {
            CellDetailsRow(techFormatter.country(), country)
            if let country = netCountry {
                NavigationLink {
                    CountryDetailsView(country: country)
                } label: {
                    CellDetailsRow("Country", country.shortName)
                }
            }
            CellDetailsRow(techFormatter.network(), formatMNC(network))
            if let netOperator = netOperator, let operatorName = netOperator.combinedName {
                NavigationLink {
                    OperatorDetailsView(netOperator: netOperator)
                } label: {
                    CellDetailsRow("Network", operatorName)
                }
            }
        }
    }
}
