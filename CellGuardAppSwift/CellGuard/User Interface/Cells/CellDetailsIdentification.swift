//
//  CellDetailsIdentification.swift
//  CellGuard
//
//  Created by Lukas Arnold on 15.09.24.
//

import SwiftUI

struct CellDetailsIdentification: View {
    
    let technology: ALSTechnology?
    let cellId: Int64
    
    init(cell: Cell) {
        self.technology = ALSTechnology(rawValue: cell.technology?.uppercased() ?? "")
        self.cellId = cell.cell
    }
    
    init(technology: ALSTechnology, cellId: Int64) {
        self.technology = technology
        self.cellId = cellId
    }
    
    var body: some View {
        switch technology {
        case .GSM:
            CellIdentificationGSM(cellId: cellId)
        case .UMTS:
            CellIdentificationUMTS(lcid: cellId)
        case .LTE:
            CellIdentificationLTE(eci: cellId)
        case .NR:
            CellIdentificationNR(nci: cellId)
        default:
            EmptyView()
        }
    }
    
}

private struct CellIdentificationGSM: View {
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
        }
    }
}

private struct CellIdentificationUMTS: View {
    let lcid: Int64
    
    var body: some View {
        Group {
            // UTRAN Cell ID (LCID) -> 28 Bits
            let (rnc, cellId) = CellIdentification.umts(lcid: lcid)
            
            // Radio Network Controller (RNC) -> 12 Bits
            KeyValueListRow(key: "RNC ID", value: String(rnc))
            // Cell ID (CID) -> 16 Bits
            KeyValueListRow(key: "Cell ID", value: String(cellId))
        }
    }
}

private struct CellIdentificationLTE: View {
    let eci: Int64
    
    var body: some View {
        Group {
            // E-UTRAN Cell Identity (ECI) -> 28 Bits
            let (eNodeB, sector) = CellIdentification.lte(eci: eci)
            
            // eNodeB ID (Base Station) -> 20 Bits
            KeyValueListRow(key: "eNodeB ID", value: String(eNodeB))
            // Sector ID -> 8 Bits
            KeyValueListRow(key: "Sector ID", value: String(sector))
        }
    }
}

private struct CellIdentificationNR: View {
    let nci: Int64
    
    // A sensible default value which hopefully works for most networks
    @State private var showSectorIdLengthSlider = false
    @State private var sectorIdLengthSlider: Double = 8
    
    init(nci: Int64) {
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
            CellIdentificationGSM(cellId: 20336)
        }
        Section(header: Text("UMTS")) {
            // TODO: Find correct UMTS cell id
            CellIdentificationUMTS(lcid: 0)
        }
        Section(header: Text("LTE")) {
            CellIdentificationLTE(eci: 27177984)
        }
        Section(header: Text("NR")) {
            CellIdentificationNR(nci: 21248033539)
        }
    }
}
