//
//  AbstractListView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 12.01.23.
//

import Foundation
import SwiftUI

enum ListViewLevel {
    case country
    case network
    case area
    case cell
    
    var name: String {
        switch self {
        case .country:
            return "Country"
        case .network:
            return "Network"
        case .area:
            return "Area"
        case .cell:
            return "Cell"
        }
    }
    
    var column: String {
        switch self {
        case .country:
            return "mcc"
        case .network:
            return "network"
        case .area:
            return "area"
        case .cell:
            return "cellId"
        }
    }
    
    var next: ListViewLevel {
        switch self {
        case .country:
            return .network
        case .network:
            return .area
        case .area:
            return .cell
        case .cell:
            return .cell
        }
    }
    
    func extractValue(cell: Cell) -> Int64 {
        switch self {
        case .country:
            return Int64(cell.country)
        case .network:
            return Int64(cell.network)
        case .area:
            return Int64(cell.area)
        case .cell:
            return cell.cell
        }
    }
}

struct ListView: View {
    
    var body: some View {
        NavigationView {
            LevelListView()
        }
    }
    
}

struct LevelListView: View {
    
    private let level: ListViewLevel
    private let selectors: [ListViewLevel : Int64]
    @FetchRequest private var items: FetchedResults<TweakCell>
    
    init() {
        self.init(level: .country, selectors: [:])
    }
    
    init(level: ListViewLevel, selectors: [ListViewLevel : Int64]) {
        self.level = level
        self.selectors = selectors
        
        // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Predicates/Articles/pSyntax.html#//apple_ref/doc/uid/TP40001795-SW1
        var predicates: [NSPredicate] = []
        
        selectors.forEach { selectorLevel, selectorValue in
            // It's very important to convert non-strings to NSObjects, otherwise the app crashes
            // https://stackoverflow.com/a/25613121
            predicates.append(NSPredicate(format: "%K == %@", selectorLevel.column, selectorValue as NSObject))
        }
        
        // https://www.hackingwithswift.com/books/ios-swiftui/dynamically-filtering-fetchrequest-with-swiftui
        self._items = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \TweakCell.collected, ascending: true)],
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: predicates),
            animation: .default
        )
    }
    
    var body: some View {
        // Group cells by day.
        // We're unable to compute this property in the database as the user can travel, therefore changing its timezone, and thus starting the day at a different time.
        let itemsGroupedByDay = Dictionary(grouping: items.filter { $0.collected != nil }) { item in
            Calendar.current.startOfDay(for: item.collected!)
        }.sorted(by: {$0.key > $1.key})
        
        // TODO: Ensure cells are only listed once per day
        
        // Embed in a VStack to make items collapsible:
        VStack {
            List {
                ForEach(itemsGroupedByDay, id: \.key) { key, cells in
                    Section(header: Text(key, formatter: self.dateFormatter)) {
                        /* ForEach(cells, id: \.self) { cell in
                            ListBodyElement(level: level, selectors: selectors, cell: cell)
                        } */
                        
                        ForEach(removeDuplicates(cells: cells, key: { level.extractValue(cell: $0) }), id: \.self) { cell in
                            ListBodyElement(level: level, selectors: selectors, cell: cell)
                        }
                    }
                }
            }
        }
        .navigationTitle(level == .country ? "List" : level.name)
        .navigationBarTitleDisplayMode(level == .country ? .automatic : .inline)
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    private func removeDuplicates<T: Hashable>(cells: [TweakCell], key: (TweakCell) -> T) -> [Cell] {
        var unique: [T : TweakCell] = [:]
        for cell in cells {
            if unique[key(cell)] == nil {
                unique[key(cell)] = cell
            }
        }
        
        return unique.values.sorted(by: {$0.collected! > $1.collected!})
    }
}

private struct ListBodyElement: View {
    
    let level: ListViewLevel
    let selectors: [ListViewLevel : Int64]
    let cell: Cell
    
    var body: some View {
        var newSelectors = selectors
        newSelectors[level] = level.extractValue(cell: cell)
        
        return NavigationLink {
            if level == .cell {
                CellDetailsView(cell: cell)
            } else {
                LevelListView(level: level.next, selectors: newSelectors)
            }
        } label: {
            Text("\(level.extractValue(cell: cell) as NSNumber, formatter: numberFormatter)")
        }
    }
    
    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.usesSignificantDigits = false
        return formatter
    }()
    
}

struct ListView_Previews: PreviewProvider {
    static var previews: some View {
        ListView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
