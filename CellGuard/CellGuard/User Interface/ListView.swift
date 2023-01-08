//
//  DetailsView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.01.23.
//

import Foundation
import SwiftUI

struct ListView: View {
    
    // https://developer.apple.com/documentation/swiftui/loading_and_displaying_a_large_data_feed
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Cell.timestamp, ascending: true)],
        // TODO: Add predicate to only show cells from the tweak: NSPredicate(format: "source."),
        animation: .default)
    private var items: FetchedResults<Cell>

    
    var body: some View {
        let calendar = Calendar.current
        let itemsGroupedByDay = Dictionary(grouping: items.filter { $0.timestamp != nil }) { item in
            // TODO: Does this work in all timezones?
            calendar.date(bySettingHour: 0, minute: 0, second: 0, of: item.timestamp!)!
        }
        
        NavigationView {
            // Embed in a VStack to make items collapsible:
            VStack {
                List {
                    ForEach(itemsGroupedByDay.sorted(by: {$0.key > $1.key}), id: \.key) { key, cells in
                        Section(header: Text(key, formatter: dateFormatter)) {
                            ForEach(cells, id: \.self) { cell in
                                NavigationLink {
                                    CellDetailsView(cell: cell)
                                } label: {
                                    // TODO: Think of a better
                                    Text("\(cell.mcc) - \(cell.network) - \(cell.area as NSNumber, formatter: numberFormatter) - \(cell.cellId as NSNumber, formatter: numberFormatter)")
                                }
                            }

                        }
                    }
                }
                .navigationTitle("List")
            }
        }
    }
}

private let numberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.usesSignificantDigits = false
    return formatter
}()

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

struct ListView_Previews: PreviewProvider {
    static var previews: some View {
        ListView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
