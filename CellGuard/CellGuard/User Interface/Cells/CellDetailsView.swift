//
//  CellDetailsView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.01.23.
//

import SwiftUI
import MapKit

struct CellDetailsView: View {
    
    let cell: Cell
    private let techFormatter: CellTechnologyFormatter
    
    @FetchRequest private var alsCells: FetchedResults<ALSCell>
    @FetchRequest private var tweakCells: FetchedResults<TweakCell>
    
    init(cell: Cell) {
        self.cell = cell
        self.techFormatter = CellTechnologyFormatter.from(technology: cell.technology)
        
        self._alsCells = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \ALSCell.imported, ascending: false)],
            predicate: PersistenceController.shared.sameCellPredicate(cell: cell),
            animation: .default
        )
        self._tweakCells = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \TweakCell.collected, ascending: false)],
            predicate: PersistenceController.shared.sameCellPredicate(cell: cell),
            animation: .default
        )
    }
    
    var body: some View {
        let (countryName, networkName) = OperatorDefinitions.shared.translate(country: cell.country, network: cell.network)
        
        List {
            if SingleCellMap.hasAnyLocation(alsCells, tweakCells) {
                SingleCellMap(alsCells: alsCells, tweakCells: tweakCells)
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
            
            Section(header: Text("Cellular Technology")) {
                CellDetailsRow("Technology", cell.technology ?? "Unknown")
                CellDetailsRow(techFormatter.frequency(), cell.frequency)
                if let tweakCell = cell as? TweakCell {
                    NavigationLink {
                        CellJSONDataView(cell: tweakCell)
                    } label: {
                        Text("View Details")
                    }
                }
            }
            
            Section(header: Text("Cell Identification")) {
                CellDetailsRow("Country", countryName ?? "???")
                CellDetailsRow(techFormatter.country(), cell.country)
                CellDetailsRow("Network", networkName ?? "???")
                CellDetailsRow(techFormatter.network(), cell.network)
                CellDetailsRow(techFormatter.area(), cell.area)
                CellDetailsRow(techFormatter.cell(), cell.cell)
            }
            
            Section(header: Text("Verification")) {
                CellDetailsRow("Status", cellStatusDescription())
                if let tweakCell = cell as? TweakCell {
                    CellDetailsRow("Score", "\(tweakCell.score)")
                }
                if let alsImported = alsCells.first?.imported {
                    CellDetailsRow("Fetched", mediumDateTimeFormatter.string(from: alsImported))
                }
                if let reach = alsCells.first?.location?.reach {
                    CellDetailsRow("ALS Reach", "\(reach)m")
                }
                if let score = alsCells.first?.location?.score {
                    CellDetailsRow("ALS Score", "\(score)")
                }
            }
            
            if !tweakCells.isEmpty {
                let dateTweakCells = tweakCells.filter { $0.collected != nil }
                let firstCell = dateTweakCells.sorted(by: { $0.collected! < $1.collected! }).first
                let lastCell = dateTweakCells.sorted(by: { $0.collected! < $1.collected! }).last
                
                Section(header: Text("Recorded Measurements")) {
                    // TODO: Show list of timestamps of all measurements which link to the recorded JSON data
                    CellDetailsRow("Count", tweakCells.count)
                    if let firstCell = firstCell {
                        CellDetailsRow("First Seen", mediumDateTimeFormatter.string(from: firstCell.collected!))
                    }
                    if let lastCell = lastCell {
                        CellDetailsRow("Last Seen", mediumDateTimeFormatter.string(from: lastCell.collected!))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("\(cell.technology ?? "Unknown") Cell")
    }
    
    private func cellStatusDescription() -> String {
        // TODO: Change this
        if cell is ALSCell {
            return "Verified"
        } else if let tweakCell = cell as? TweakCell {
            if tweakCell.status != nil, let status = CellStatus(rawValue: tweakCell.status!) {
                return status.humanDescription()
            }
        }
        
        return "Unknown"
    }

}

struct CellDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        let viewContext = PersistenceController.preview.container.viewContext
        let cell = PersistencePreview.alsCell(context: viewContext)

        let tweakCell = PersistencePreview.tweakCell(context: viewContext, from: cell)
        _ = PersistencePreview.tweakCell(context: viewContext, from: cell)
        _ = PersistencePreview.tweakCell(context: viewContext, from: cell)
        _ = PersistencePreview.tweakCell(context: viewContext, from: cell)
        
        do {
            try viewContext.save()
        } catch {
            
        }
        
        PersistenceController.preview.fetchPersistentHistory()
        
        return NavigationView {
            CellDetailsView(
                cell: tweakCell //PersistencePreview.alsCell(context: viewContext)
            )
        }
        .environment(\.managedObjectContext, viewContext)
    }
}
