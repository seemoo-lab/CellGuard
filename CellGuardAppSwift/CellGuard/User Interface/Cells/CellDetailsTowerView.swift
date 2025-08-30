//
//  CellDetailsTower.swift
//  CellGuard
//
//  Created by Lukas Arnold on 19.10.24.
//

import SwiftUI
import NavigationBackport

struct CellDetailsTowerNavigation: Hashable {
    let technology: ALSTechnology
    let country: Int32
    let network: Int32
    let area: Int32
    let baseStation: Int64
    let bitCount: Int?

    init(technology: ALSTechnology, country: Int32, network: Int32, area: Int32, baseStation: Int64, bitCount: Int? = nil) {
        self.technology = technology
        self.country = country
        self.network = network
        self.area = area
        self.baseStation = baseStation
        self.bitCount = bitCount
    }
}

struct CellDetailsTowerView: View {

    let technology: ALSTechnology
    let country: Int32
    let network: Int32
    let area: Int32
    let baseStation: Int64
    let bitCount: Int?

    private let techFormatter: CellTechnologyFormatter
    private let dissect: (Int64) -> (Int64, Int64)

    init(nav: CellDetailsTowerNavigation) {
        self.technology = nav.technology
        self.country = nav.country
        self.network = nav.network
        self.area = nav.area
        self.baseStation = nav.baseStation
        self.bitCount = nav.bitCount

        self.techFormatter = CellTechnologyFormatter(technology: technology)
        self.dissect = switch technology {
        case .GSM: CellIdentification.gsm
        case .UMTS: CellIdentification.umts
        case .LTE: CellIdentification.lte
        case .NR: { CellIdentification.nr(nci: $0, sectorIdLength: nav.bitCount ?? 0) }
        default: { (0, $0) }
        }
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
                DetailsRow("Technology", technology.rawValue)
                DetailsRow(techFormatter.area(), area)
            }
            Section(header: Text("Tower"), footer: Text("The tower's approximate position is the center of its cell's locations. Connect to more cells to improve the position's accuracy.")) {
                DetailsRow(baseStationIDSingle, baseStation)
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
    @ObservedObject private var locationInfo = LocationDataManagerPublished.shared

    init(baseStation: Int64, dissect: @escaping (Int64) -> (Int64, Int64), fetchRequest: FetchRequest<CellALS>) {
        self.baseStation = baseStation
        self.dissect = dissect
        self._cells = fetchRequest
    }

    var body: some View {
        // TODO: Show sector id instead of provider name / network
        ExpandableMap {
            TowerCellMap(locationInfo: locationInfo, alsCells: cells.filter { dissect($0.cell).0 == baseStation }, dissect: dissect)
        }
        .nbNavigationDestination(for: ExpandableMapInfo.self) { _ in
            TowerCellMap(locationInfo: locationInfo, alsCells: cells.filter { dissect($0.cell).0 == baseStation }, dissect: dissect)
                .ignoresSafeArea()
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

    func plainCellId(_ cell: CellALS) -> String {
        let cellId = dissect(cell.cell).1 as NSNumber
        return plainNumberFormatter.string(from: cellId) ?? "err"
    }

    var body: some View {
        Section(header: Text("Cells")) {
            ForEach(filteredCells, id: \.id) { (cell: CellALS) in
                ListNavigationLink(value: NavObjectId(object: cell)) {
                    Text(plainCellId(cell))
                }
            }
        }
    }

}

#Preview {
    // CellDetailsTower()
}
