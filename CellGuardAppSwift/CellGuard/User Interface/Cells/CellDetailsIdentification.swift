//
//  CellDetailsIdentification.swift
//  CellGuard
//
//  Created by Lukas Arnold on 15.09.24.
//

import SwiftUI
import NavigationBackport

struct CellDetailsIdentification: View {

    let technology: ALSTechnology?
    let cell: Cell

    init(cell: Cell) {
        self.technology = ALSTechnology(rawValue: cell.technology?.uppercased() ?? "")
        self.cell = cell
    }

    var body: some View {
        let country = cell.country
        let network = cell.network
        let area = cell.area
        let cellId = cell.cell

        switch technology {
        case .GSM:
            CellIdentificationGSM(country: country, network: network, area: area, cellId: cellId)
        case .UMTS:
            CellIdentificationUMTS(country: country, network: network, area: area, lcid: cellId)
        case .LTE:
            CellIdentificationLTE(country: country, network: network, area: area, eci: cellId)
        case .NR:
            CellIdentificationNR(country: country, network: network, area: area, nci: cellId)
        default:
            EmptyView()
        }
    }

}

private struct CellIdentificationGSM: View {
    let country: Int32
    let network: Int32
    let area: Int32
    let cellId: Int64

    var body: some View {
        Group {
            let (bts, sector) = CellIdentification.gsm(cellId: cellId)

            // Base Transceiver Station -> First five numbers
            KeyValueListRow(key: "BTS ID", value: String(bts))

            // Sector ID -> Last number
            // 0 = omnidirectional antenna
            // 1, 2, 3 = bisector or trisector antennas
            KeyValueListRow(key: "Sector ID", value: String(sector))

            KeyValueListRow(key: "Antennas", value: sector == 0 ? "Omnidirectional" : "Bi- or tridirectional")

            NBNavigationLink(value: CellDetailsTowerNavigation(technology: .GSM, country: country, network: network, area: area, baseStation: bts)) {
                Text("Show Details")
            }
        }
    }
}

private struct CellIdentificationUMTS: View {
    let country: Int32
    let network: Int32
    let area: Int32
    let lcid: Int64

    var body: some View {
        Group {
            // UTRAN Cell ID (LCID) -> 28 Bits
            let (rnc, cellId) = CellIdentification.umts(lcid: lcid)

            // Radio Network Controller (RNC) -> 12 Bits
            KeyValueListRow(key: "RNC ID", value: String(rnc))

            // Cell ID (CID) -> 16 Bits
            KeyValueListRow(key: "Cell ID", value: String(cellId))

            NBNavigationLink(value: CellDetailsTowerNavigation(technology: .UMTS, country: country, network: network, area: area, baseStation: rnc)) {
                Text("Show Details")
            }
        }
    }
}

private struct CellIdentificationLTE: View {
    let country: Int32
    let network: Int32
    let area: Int32
    let eci: Int64

    var body: some View {
        Group {
            // E-UTRAN Cell Identity (ECI) -> 28 Bits
            let (eNodeB, sector) = CellIdentification.lte(eci: eci)

            // eNodeB ID (Base Station) -> 20 Bits
            KeyValueListRow(key: "eNodeB ID", value: String(eNodeB))

            // Sector ID -> 8 Bits
            KeyValueListRow(key: "Sector ID", value: String(sector))

            NBNavigationLink(value: CellDetailsTowerNavigation(technology: .LTE, country: country, network: network, area: area, baseStation: eNodeB)) {
                Text("Show Details")
            }
        }
    }
}

private struct CellIdentificationNR: View {
    let country: Int32
    let network: Int32
    let area: Int32
    let nci: Int64

    // A sensible default value which hopefully works for most networks
    @State private var showSectorIdLengthSlider = false
    @State private var sectorIdLengthSlider: Double = 8

    init(country: Int32, network: Int32, area: Int32, nci: Int64) {
        self.country = country
        self.network = network
        self.area = area
        self.nci = nci
    }

    var body: some View {
        // https://5g-tools.com/5g-nr-cell-identity-nci-calculator/
        Group {
            // NR Cell Identity (NCI) -> 36 Bits
            let (gNodeB, sector) = CellIdentification.nr(nci: nci, sectorIdLength: Int(sectorIdLengthSlider))

            // gNodeB ID (Base Station) -> 22..32 Bits (customizable)
            let sectorIdLength = Int(sectorIdLengthSlider)
            KeyValueListRow(key: "gNodeB ID (\(32 - (sectorIdLength - 4)) Bits)", value: String(gNodeB))

            // Sector ID -> 4..14 Bits
            KeyValueListRow(key: "Sector ID (\(sectorIdLength) Bits)", value: String(sector))

            if showSectorIdLengthSlider {
                Slider(
                    value: $sectorIdLengthSlider,
                    in: 4...14,
                    step: 1,
                    label: {
                        Text("Sector ID Bits")
                    }
                )
            }

            NBNavigationLink(value: CellDetailsTowerNavigation(technology: .NR, country: country, network: network, area: area, baseStation: gNodeB, bitCount: sectorIdLength)) {
                Text("Show Details")
            }
        }
        .contextMenu {
            Button {
                showSectorIdLengthSlider = !showSectorIdLengthSlider
            } label: {
                Label("Change bit distribution", systemImage: "gear")
            }
        }
    }
}

#Preview {
    List {
        Section(header: Text("GSM")) {
            CellIdentificationGSM(country: 0, network: 0, area: 0, cellId: 20336)
        }
        Section(header: Text("UMTS")) {
            CellIdentificationUMTS(country: 0, network: 0, area: 0, lcid: 869081)
        }
        Section(header: Text("LTE")) {
            CellIdentificationLTE(country: 0, network: 0, area: 0, eci: 27177984)
        }
        Section(header: Text("NR")) {
            CellIdentificationNR(country: 0, network: 0, area: 0, nci: 21248033539)
        }
    }
}
