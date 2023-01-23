//
//  CellInformation.swift
//  CellGuard
//
//  Created by Lukas Arnold on 16.01.23.
//

import SwiftUI
import MapKit

struct CellInformationCard: View {
    
    let dateFormatter = RelativeDateTimeFormatter()
    let cell: TweakCell
    
    @FetchRequest private var alsCells: FetchedResults<ALSCell>
    @FetchRequest private var tweakCells: FetchedResults<TweakCell>
    
    private let techFormatter: CellTechnologyFormatter
    
    init(cell: TweakCell) {
        self.cell = cell
        // TODO: Ensure that
        self.techFormatter = CellTechnologyFormatter.from(technology: cell.technology)
        
        self._alsCells = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \ALSCell.imported, ascending: true)],
            predicate: PersistenceController.shared.sameCellPredicate(cell: cell),
            animation: .default
        )
        self._tweakCells = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \TweakCell.collected, ascending: true)],
            predicate: PersistenceController.shared.sameCellPredicate(cell: cell),
            animation: .default
        )

    }
    
    var body: some View {
        VStack {
            HStack {
                Text("Active Cell")
                    .font(.title2)
                    .bold()
                Spacer()
                CellStatusIcon(text: cell.status)
            }
            .padding(EdgeInsets(top: 20, leading: 20, bottom: 10, trailing: 20))
            
            HStack {
                CellInformationItem(title: techFormatter.country(), number: cell.country)
                CellInformationItem(title: techFormatter.network(), number: cell.network)
                CellInformationItem(title: techFormatter.area(), number: cell.area)
                CellInformationItem(title: techFormatter.cell(), number: cell.cell)
            }
            .padding(EdgeInsets(top: 5, leading: 15, bottom: 10, trailing: 15))
            
            HStack {
                CellInformationItem(title: "Technology", text: cell.technology)
                // CellInformationItem(title: techFormatter.frequency(), number: cell.frequency)
                CellInformationItem(
                    title: "Date",
                    text: dateFormatter.localizedString(for: cell.collected ?? cell.imported ?? Date(), relativeTo: Date())
                )
            }
            .padding(EdgeInsets(top: 5, leading: 20, bottom: cell.location == nil ? 25 : 10, trailing: 20))
            
            if SingleCellMap.hasAnyLocation(alsCells, tweakCells) {
                SingleCellMap(alsCells: alsCells, tweakCells: tweakCells)
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
        }
        .frame(maxWidth: .infinity)
        .cornerRadius(10)
        .background(
            RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 8)
        )
        // .foregroundColor(.white)
        .padding()
    }
}

private struct CellInformationItem: View {
    
    let title: String
    let text: String?
    
    init(title: String, number: Int32) {
        self.title = title
        self.text = plainNumberFormatter.string(from: number as NSNumber)
    }
    
    init(title: String, number: Int64) {
        self.title = title
        self.text = plainNumberFormatter.string(from: number as NSNumber)
    }
    
    init(title: String, text: String?) {
        self.title = title
        self.text = text
    }
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
            Text(text ?? "-")
        }
        .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
    }
    
}

private struct CoordinateIdentifable: Identifiable {
    
    let index: Int
    
    init(_ index: Int) {
        self.index = index
    }
    
    var id: Int {
        return index
    }
}

struct CellInformation_Previews: PreviewProvider {
    static var previews: some View {
        CellInformationCard(cell: exampleCell())
            .previewDisplayName("iPhone 14 Pro")
        
        /* CellInformationView(cell: exampleCell())
            .previewDevice("iPhone SE (3rd generation)")
            .previewDisplayName("iPhone SE") */
    }
    
    private static func exampleCell() -> TweakCell {
        let context = PersistenceController.preview.container.viewContext
        
        let location = UserLocation(context: context)
        location.latitude = 49.8726737
        location.longitude = 8.6516291
        location.horizontalAccuracy = 2
        location.collected = Date()
        location.imported = Date()
        
        let cell = TweakCell(context: PersistenceController.preview.container.viewContext)
        cell.status = CellStatus.imported.rawValue
        cell.technology = "LTE"
        cell.frequency = 1600
        
        cell.country = 262
        cell.network = 2
        cell.area = 46452
        cell.cell = 15669002
        
        cell.collected = Date(timeIntervalSinceNow: -60 * 4)
        cell.imported = Date(timeIntervalSinceNow: -60 * 1)
        // cell.location = location
                
        return cell
    }
}
