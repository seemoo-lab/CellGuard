//
//  OperatorDetailsView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 02.04.25.
//

import SwiftUI

struct OperatorDetailsView: View {
    let netOperator: NetworkOperator

    init(netOperator: NetworkOperator) {
        self.netOperator = netOperator
    }

    var body: some View {
        List {
            Section(header: Text("Country")) {
                CellDetailsRow("MCC", netOperator.mcc)
                CellDetailsRow("Name", netOperator.shortCountryName)
                if let wikipediaUrl = netOperator.wikipediaCountryUrl {
                    Link(destination: wikipediaUrl) {
                        KeyValueListRow(key: "View on Wikipedia") {
                            wikipediaIcon
                        }
                    }
                }
            }

            Section(header: Text("Network")) {
                CellDetailsRow("MNC", netOperator.mnc)
                CellDetailsRow("Status", netOperator.status.humanString())
            }

            if let brandName = netOperator.brandName {
                Section(header: Text("Brand")) {
                    Text(brandName)
                    if let wikipediaUrl = netOperator.wikipediaBrandUrl {
                        Link(destination: wikipediaUrl) {
                            KeyValueListRow(key: "View on Wikipedia") {
                                wikipediaIcon
                            }
                        }
                    }
                }
            }

            if let operatorName = netOperator.operatorName {
                Section(header: Text("Operator")) {
                    Text(operatorName)
                    if let wikipediaUrl = netOperator.wikipediaOperatorUrl {
                        Link(destination: wikipediaUrl) {
                            KeyValueListRow(key: "View on Wikipedia") {
                                wikipediaIcon
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Network Operator")
    }
}

#Preview("DE Telekom") {
    NavigationView {
        OperatorDetailsView(netOperator: OperatorDefinitions.shared.translate(country: 262, network: 01)!)
    }
}

#Preview("BA RS Telecom") {
    NavigationView {
        OperatorDetailsView(netOperator: OperatorDefinitions.shared.translate(country: 218, network: 05)!)
    }
}
