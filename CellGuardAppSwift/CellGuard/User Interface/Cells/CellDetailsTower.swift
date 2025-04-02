//
//  CellDetailsTower.swift
//  CellGuard
//
//  Created by Lukas Arnold on 19.10.24.
//

import SwiftUI

struct CellDetailsTower: View {
    
    let technology: ALSTechnology
    let country: Int32
    let network: Int32
    let area: Int32
    let baseStation: Int64
    let dissect: (Int64) -> (Int64, Int64)
    let bitCount: Int?
    
    private let techFormatter: CellTechnologyFormatter
    private let netCountry: NetworkCountry?
    private let netOperator: NetworkOperator?
    
    init(technology: ALSTechnology, country: Int32, network: Int32, area: Int32, baseStation: Int64, dissect: @escaping (Int64) -> (Int64, Int64), bitCount: Int? = nil) {
        self.technology = technology
        self.country = country
        self.network = network
        self.area = area
        self.baseStation = baseStation
        self.dissect = dissect
        self.bitCount = bitCount
        
        self.techFormatter = CellTechnologyFormatter(technology: technology)
        self.netCountry = OperatorDefinitions.shared.translate(country: country)
        self.netOperator = OperatorDefinitions.shared.translate(country: country, network: network)
    }
    
    var baseStationIDSingle: String {
        switch technology {
        case .GSM: "BTS ID"
        case .UMTS: "RNC ID"
        case .LTE: "eNodeB ID"
        case .NR: "gNodeB ID (\(bitCount ?? 0))"
        default: "BS ID"
        }
    }
    
    var fetchRequest: FetchRequest<CellALS> {
        let request = CellALS.fetchRequest()
        request.predicate = NSPredicate(
            format: "technology == %@ and country == %@ and network == %@ and area == %@",
            technology.rawValue, Int(country) as NSNumber, Int(network) as NSNumber, Int(area) as NSNumber
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CellALS.cell, ascending: true)]
        return FetchRequest(fetchRequest: request)
    }
    
    var body: some View {
        List {
            CellDetailsTowerMap(baseStation: baseStation, dissect: dissect, fetchRequest: fetchRequest)
            
            CellCountryNetworkSection(country: country, network: network, techFormatter: techFormatter)
            Section(header: Text("Technology & Region")) {
                CellDetailsRow("Technology", technology.rawValue)
                CellDetailsRow(techFormatter.area(), area)
            }
            Section(header: Text("Tower"), footer: Text("The tower's approximate position is the center of its cell's locations. Connect to more cells to improve the position's accuracy.")) {
                CellDetailsRow(baseStationIDSingle, baseStation)
            }
            CellDetailsList(technology: technology, baseStation: baseStation, dissect: dissect, fetchRequest: fetchRequest)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("\(technology.rawValue) Cell Tower")
    }
}

private struct CellDetailsTowerMap: View {
    
    let baseStation: Int64
    let dissect: (Int64) -> (Int64, Int64)
    
    @FetchRequest private var cells: FetchedResults<CellALS>
    
    init(baseStation: Int64, dissect: @escaping (Int64) -> (Int64, Int64), fetchRequest: FetchRequest<CellALS>) {
        self.baseStation = baseStation
        self.dissect = dissect
        self._cells = fetchRequest
    }
    
    var body: some View {
        // TODO: Show sector id instead of provider name / network
        ExpandableMap {
            TowerCellMap(alsCells: cells.filter { dissect($0.cell).0 == baseStation }, dissect: dissect)
        }
    }
    
}

private struct CellDetailsList: View {
    
    let technology: ALSTechnology
    let baseStation: Int64
    let dissect: (Int64) -> (Int64, Int64)
    
    @FetchRequest private var cells: FetchedResults<CellALS>
    
    init(technology: ALSTechnology, baseStation: Int64, dissect: @escaping (Int64) -> (Int64, Int64), fetchRequest: FetchRequest<CellALS>) {
        self.technology = technology
        self.baseStation = baseStation
        self.dissect = dissect
        self._cells = fetchRequest
    }
    
    var filteredCells: [CellALS] {
        cells.filter { dissect($0.cell).0 == baseStation }
    }
    
    var body: some View {
        Section(header: Text("Cells")) {
            ForEach(filteredCells, id: \.id) { (cell: CellALS) in
                NavigationLink(destination: CellDetailsView(alsCell: cell)) {
                    Text("\(dissect(cell.cell).1)")
                }
            }
        }
    }
    
}

#Preview {
    // CellDetailsTower()
}
