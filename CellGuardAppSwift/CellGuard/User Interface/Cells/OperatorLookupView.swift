//
//  OperatorLookupView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 18.06.25.
//

import SwiftUI
import NavigationBackport

// This view is only intended to be used for testing various country & network values.
struct OperatorLookupView: View {

    @State private var country: Int? = 262
    @State private var network: Int? = 01
    @State private var technology: ALSTechnology = .LTE

    var body: some View {
        Form {
            Section(header: Text("Operator Attributes")) {
                LabelNumberField("Country", "MCC", $country)
                LabelNumberField("Network", "MNC", $network)
                Picker("Technology", selection: $technology) {
                    ForEach(ALSTechnology.allCases) { Text($0.rawValue).tag($0) }
                }
            }

            ListNavigationLink(value: SingleCellCountryNetworkNav(
                country: Int32(truncatingIfNeeded: country ?? 0),
                network: Int32(truncatingIfNeeded: network ?? 0),
                technology: technology)
            ) {
                Text("Country & Network Data")
            }
            .disabled(country == nil || network == nil)
        }
        .navigationTitle("Operator Lookup")
    }
}
