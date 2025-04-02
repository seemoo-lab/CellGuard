//
//  CountryDetails.swift
//  CellGuard
//
//  Created by Lukas Arnold on 02.04.25.
//

import SwiftUI

struct CountryDetailsView: View {
    let country: NetworkCountry
    
    var body: some View {
        List {
            Section {
                CellDetailsRow("Name", country.name)
                CellDetailsRow("ISO", country.iso)
                if let wikipediaUrl = country.wikipediaMncUrls {
                    Link(destination: wikipediaUrl) {
                        KeyValueListRow(key: "View on Wikipedia") {
                            wikipediaIcon
                        }
                    }
                }
            }
            
            Section(header: Text("Mobile Country Codes")) {
                ForEach(country.listMccs()) {
                    Text($0.mcc)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Country")
    }
}

#Preview("DE") {
    NavigationView {
        CountryDetailsView(country: OperatorDefinitions.shared.countriesByIso["DE"]!.first!)
    }
}

#Preview("US") {
    NavigationView {
        CountryDetailsView(country: OperatorDefinitions.shared.countriesByIso["US"]!.first!)
    }
}

#Preview("DK") {
    NavigationView {
        CountryDetailsView(country: OperatorDefinitions.shared.countriesByIso["DK"]!.first!)
    }
}
