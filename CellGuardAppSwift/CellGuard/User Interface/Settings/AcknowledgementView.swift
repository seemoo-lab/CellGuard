//
//  AcknowledgementView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 10.04.24.
//

import SwiftUI
import AcknowList
import SwiftGzip
import NavigationBackport

struct CargoLicenseFile: Codable {
    var rootName: String
    var thirdPartyLibraries: [CargoThirdPartyLibrary]
}

struct CargoThirdPartyLibrary: Codable {
    var packageName: String
    var packageVersion: String
    var repository: String
    var license: String
    var licenses: [CargoLicense]
}

struct CargoLicense: Codable {
    var license: String
    var text: String
}

struct AcknowledgementView: View {

    var body: some View {
        List {
            NBNavigationLink(value: SummaryNavigationPath.acknowledgementsSwift) {
                Text("Swift")
            }
            NBNavigationLink(value: SummaryNavigationPath.acknowledgementsRust) {
                Text("Rust")
            }
        }
        .navigationTitle("Third-Party Libraries")
        .listStyle(.insetGrouped)
    }

}

struct SwiftAcknowledgementView: View {

    @State private var swiftAcknowledgements: [Acknow] = []

    private func loadSwiftAcknowledgements () {
        var acknowledgements: [Acknow] = []

        if let url = Bundle.main.url(forResource: "Package", withExtension: "resolved"),
              let data = try? Data(contentsOf: url),
              let acknowList = try? AcknowPackageDecoder().decode(from: data) {
            acknowledgements = acknowList.acknowledgements
        } else {
            acknowledgements = []
        }

        if let url = Bundle.main.url(forResource: "macos-unifiedlogs-license", withExtension: "txt"),
           let data = try? Data(contentsOf: url) {
            acknowledgements.append(Acknow(
                title: "macos-unifiedlogs",
                text: String(data: data, encoding: .utf8)
            ))
        }

        acknowledgements.sort { $0.title < $1.title }
        self.swiftAcknowledgements = acknowledgements
    }

    var body: some View {
        AcknowListSwiftUIView(acknowledgements: swiftAcknowledgements)
            .onAppear {
                if swiftAcknowledgements.isEmpty {
                    loadSwiftAcknowledgements()
                }
            }
    }

}

struct RustAcknowledgementView: View {

    @State private var rustAcknowledgements: [Acknow] = []

    private func loadRustAcknowledgements() {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        let decompressor = GzipDecompressor()

        guard let url = Bundle.main.url(forResource: "cargo-licenses.json", withExtension: "gz"),
              let compressedData = try? Data(contentsOf: url),
              let data = try? decompressor.unzip(data: compressedData),
              let json = try? jsonDecoder.decode(CargoLicenseFile.self, from: data) else {
            return
        }

        // Convert to Acknow type and remove duplicates
        // See: https://stackoverflow.com/a/46354989
        var seen = Set<String>()
        rustAcknowledgements = json.thirdPartyLibraries.map { library in
            if library.license.count == 0 {
                return Acknow(title: library.packageName, repository: URL(string: library.repository)!)
            } else {
                return Acknow(title: library.packageName, text: library.license + "\n\n" + library.licenses.map { $0.text }.joined(separator: "\n\n"))
            }
        }.filter { (acknow: Acknow) in
            seen.insert(acknow.title).inserted
        }
    }

    var body: some View {
        AcknowListSwiftUIView(acknowledgements: rustAcknowledgements)
            .onAppear {
                if rustAcknowledgements.isEmpty {
                    loadRustAcknowledgements()
                }
            }
    }

}
