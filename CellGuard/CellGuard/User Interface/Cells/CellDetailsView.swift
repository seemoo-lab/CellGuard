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
        List {
            // TODO: Map with all points
            
            if SingleCellMap.hasAnyLocation(alsCells, tweakCells) {
                SingleCellMap(alsCells: alsCells, tweakCells: tweakCells)
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
            
            Section(header: Text("Cellular Technology")) {
                CellDetailsRows("Technology", cell.technology ?? "Unknwon")
                CellDetailsRows(techFormatter.frequency(), cell.frequency)
                if let tweakCell = cell as? TweakCell {
                    NavigationLink {
                        CellJSONDataView(cell: tweakCell)
                    } label: {
                        Text("View Details")
                    }
                }
            }
            
            Section(header: Text("Cell Identification")) {
                CellDetailsRows(techFormatter.country(), cell.country)
                CellDetailsRows(techFormatter.network(), cell.network)
                CellDetailsRows(techFormatter.area(), cell.area)
                CellDetailsRows(techFormatter.cell(), cell.cell)
            }
            
            Section(header: Text("Verification")) {
                CellDetailsRows("Status", cellStatusDescription())
                if let alsImported = alsCells.first?.imported {
                    CellDetailsRows("Fetched", mediumDateTimeFormatter.string(from: alsImported))
                }
                if let reach = alsCells.first?.location?.reach {
                    CellDetailsRows("Reach", "\(reach)m")
                }
            }
            
            if !tweakCells.isEmpty {
                let dateTweakCells = tweakCells.filter { $0.collected != nil }
                let firstCell = dateTweakCells.sorted(by: { $0.collected! < $1.collected! }).first
                let lastCell = dateTweakCells.sorted(by: { $0.collected! < $1.collected! }).last
                
                Section(header: Text("Recorded Measurements")) {
                    CellDetailsRows("Count", tweakCells.count)
                    if let firstCell = firstCell {
                        CellDetailsRows("First Seen", mediumDateTimeFormatter.string(from: firstCell.collected!))
                    }
                    if let lastCell = lastCell {
                        CellDetailsRows("Last Seen", mediumDateTimeFormatter.string(from: lastCell.collected!))
                    }
                }
            }
            
            // TODO: If tweak cell, show button for JSON data
        }
        .listStyle(.insetGrouped)
        .navigationTitle("\(cell.technology ?? "Unknwon") Cell")
    }
    
    private func cellStatusDescription() -> String {
        if cell is ALSCell {
            return "Verified"
        } else if let tweakCell = cell as? TweakCell {
            if tweakCell.status != nil, let status = CellStatus(rawValue: tweakCell.status!) {
                return status.humanDescription()
            }
        }
        
        return "Unkown"
    }

}

private struct CellDetailsRows: View {
    
    let description: String
    let value: String
    
    init(_ description: String, _ value: Int) {
        self.init(description, value as NSNumber)
    }
    
    init(_ description: String, _ value: Int32) {
        self.init(description, value as NSNumber)
    }
    
    init(_ description: String, _ value: Int64) {
        self.init(description, value as NSNumber)
    }
    
    init(_ description: String, _ value: NSNumber) {
        self.init(description, plainNumberFormatter.string(from: value) ?? "-")
    }
    
    init(_ description: String, _ value: String) {
        self.description = description
        self.value = value
    }
    
    var body: some View {
        HStack {
            Text(description)
            Spacer()
            Text(value)
                .foregroundColor(.gray)
        }
    }
    
}

struct CellDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        let viewContext = PersistenceController.preview.container.viewContext
        let cell = PersistencePreview.alsCell(context: viewContext)

        _ = PersistencePreview.tweakCell(context: viewContext, from: cell)
        _ = PersistencePreview.tweakCell(context: viewContext, from: cell)
        _ = PersistencePreview.tweakCell(context: viewContext, from: cell)
        _ = PersistencePreview.tweakCell(context: viewContext, from: cell)
        
        do {
            try viewContext.save()
        } catch {
            
        }
        
        PersistenceController.preview.fetchPersistentHistory()
        
        return CellDetailsView(
            cell: PersistencePreview.alsCell(context: viewContext)
        )
        .environment(\.managedObjectContext, viewContext)
    }
}
