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
            CellIdentificationUMTS(cellId: cellId)
        case .LTE:
            CellIdentificationLTE(cellId: cellId)
        case .NR:
            CellIdentificationNR(cellId: cellId)
        default:
            EmptyView()
        }
    }
    
}

// https://cidresolver.truong.fi

private struct CellIdentificationGSM: View {
    let cellId: Int64
    
    var body: some View {
        // https://www.erlang.com/topic/1-686/#post-36217
        // https://en.wikipedia.org/wiki/GSM_Cell_ID
        Group {
            // Base Transceiver Station -> First five numbers
            KeyValueListRow(key: "BTS ID", value: String(cellId / 10))
            
            // Sector ID -> Last number
            // 0 = omnidirectional antenna
            // 1, 2, 3 = bisector or trisector antennas
            let sectorId = cellId % 10
            KeyValueListRow(key: "Sector ID", value: String(sectorId))
            
            KeyValueListRow(key: "Antennas", value: sectorId == 0 ? "Omnidirectional" : "Bi- or tridirectional")
        }
    }
}

private struct CellIdentificationUMTS: View {
    let cellId: Int64
    
    var body: some View {
        // https://wiki.opencellid.org/wiki/Public:CellID
        // https://en.wikipedia.org/wiki/GSM_Cell_ID#:~:text=In%20UMTS%2C%20there%20is%20a,is%20just%20the%20Cell%20ID
        Group {
            // UTRAN Cell ID (LCID) -> 28 Bits
            
            // Radio Network Controller (RNC) -> 12 Bits
            KeyValueListRow(key: "RNC ID", value: String(cellId / (1 << 16)))
            // Cell ID (CID) -> 16 Bits
            KeyValueListRow(key: "Cell ID", value: String(cellId % (1 << 16)))
        }
    }
}

private struct CellIdentificationLTE: View {
    let cellId: Int64
    
    var body: some View {
        // https://5g-tools.com/4g-lte-cell-id-eci-calculator/
        // https://telcomaglobal.com/p/formula-cell-id-eci-lte-networks
        // https://www.cellmapper.net/enbid?net=LTE
        Group {
            // E-UTRAN Cell Identity (ECI) -> 28 Bits
            
            // eNodeB ID (Base Station) -> 20 Bits
            KeyValueListRow(key: "eNodeB ID", value: String(cellId / (1 << 8)))
            // Sector ID -> 8 Bits
            KeyValueListRow(key: "Sector ID", value: String(cellId % (1 << 8)))
        }
    }
}

private struct CellIdentificationNR: View {
    let cellId: Int64
    
    @State private var sectorIdLengthSlider: Double = 14
    
    init(cellId: Int64) {
        self.cellId = cellId
    }
    
    var body: some View {
        // https://5g-tools.com/5g-nr-cell-identity-nci-calculator/
        Group {
            // NR Cell Identity (NCI) -> 36 Bits
            
            // gNodeB ID (Base Station) -> 22..32 Bits (customizable)
            let sectorIdLength = Int(sectorIdLengthSlider)
            let gNodeBID: Int64 = cellId / (1 << sectorIdLength)
            KeyValueListRow(key: "gNodeB ID (\(32 - (sectorIdLength - 4)) Bits)", value: String(gNodeBID))
            
            // Sector ID -> 4..14 Bits
            let sectorId = cellId % (1 << sectorIdLength)
            KeyValueListRow(key: "Sector ID (\(sectorIdLength) Bits)", value: String(sectorId))
            
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
}

#Preview {
    List {
        Section(header: Text("GSM")) {
            CellIdentificationGSM(cellId: 20336)
        }
        Section(header: Text("UMTS")) {
            // TODO: Find correct UMTS cell id
            CellIdentificationUMTS(cellId: 0)
        }
        Section(header: Text("LTE")) {
            CellIdentificationLTE(cellId: 27177984)
        }
        Section(header: Text("NR")) {
            CellIdentificationNR(cellId: 21255312128)
        }
    }
}
