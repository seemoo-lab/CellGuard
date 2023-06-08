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
            return "country"
        case .network:
            return "network"
        case .area:
            return "area"
        case .cell:
            return "cell"
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

private struct GroupedTweakCell: Hashable {
    
    let value: Int64
    let cells: [TweakCell]

    let anyFailed: Bool
    let lastCollected: TweakCell
    
    init(value: Int64, cells: [TweakCell]) {
        self.value = value
        self.cells = cells
        self.anyFailed = cells.first { $0.status == CellStatus.failed.rawValue } != nil
        // TODO: Ensure that cells contains at least one value
        self.lastCollected = cells.max { $0.collected! < $1.collected! }!
    }
    
    func hash(into hasher: inout Hasher) {
        value.hash(into: &hasher)
    }
}

struct CellsListView: View {
    
    var body: some View {
        LevelListView()
    }
    
}

struct LevelListView: View {
    
    private let level: ListViewLevel
    private let selectors: [ListViewLevel : Int64]
    private let day: Date?
    @FetchRequest private var items: FetchedResults<TweakCell>
    
    init() {
        self.init(level: .country, selectors: [:])
    }
    
    init(level: ListViewLevel, selectors: [ListViewLevel : Int64], day: Date? = nil) {
        self.level = level
        self.selectors = selectors
        self.day = day
        
        // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Predicates/Articles/pSyntax.html#//apple_ref/doc/uid/TP40001795-SW1
        var predicates: [NSPredicate] = []
        
        if let day = self.day {
            let nextDay = day.addingTimeInterval(60 * 60 * 24)
            predicates.append(NSPredicate(format: "collected => %@ and collected <= %@", day as NSDate, nextDay as NSDate))
        }
        
        selectors.forEach { selectorLevel, selectorValue in
            // It's very important to convert non-strings to NSObjects, otherwise the app crashes
            // https://stackoverflow.com/a/25613121
            predicates.append(NSPredicate(format: "%K == %@", selectorLevel.column, selectorValue as NSObject))
        }
        
        // https://www.hackingwithswift.com/books/ios-swiftui/dynamically-filtering-fetchrequest-with-swiftui
        self._items = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \TweakCell.collected, ascending: false)],
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: predicates),
            animation: .default
        )
    }
    
    var body: some View {
        // TODO: Replace with cell timeline
        
        // Group cells by day
        let itemsGroupedByDay = groupDay()
        
        // Embed in a VStack to make items collapsible
        VStack {
            if itemsGroupedByDay.isEmpty {
                Text("Nothing collected so far")
            } else {
                List {
                    ForEach(itemsGroupedByDay, id: \.key) { key, cells in
                        Section(header: Text(key, formatter: mediumDateFormatter)) {
                            ForEach(groupLevel(cells: cells), id: \.value) { groupedCells in
                                ListBodyElement(level: level, selectors: selectors, groupedCells: groupedCells)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(level == .country ? "Connected Cells" : level.name)
        .navigationBarTitleDisplayMode(level == .country ? .automatic : .inline)
    }
    
    private func groupLevel(cells: [TweakCell]) -> [GroupedTweakCell] {
        Dictionary(grouping: cells, by: { level.extractValue(cell: $0) })
            .map { GroupedTweakCell(value: $0, cells: $1) }
            // TODO: Should we sort by number of by last collected?
            // Sort by value: .sorted { $0.value < $1.value }
            .sorted { $0.lastCollected.collected! < $1.lastCollected.collected! }
    }
    
    private func groupDay() -> [(key: Date, value: [TweakCell])] {
        // We're unable to compute this property in the database as the user can travel, therefore changing its timezone, and thus starting the day at a different time.
        return Dictionary(grouping: items.filter { $0.collected != nil }) { item in
            Calendar.current.startOfDay(for: item.collected!)
        }.sorted(by: {$0.key > $1.key})
    }
}

private struct ListBodyElement: View {
    
    let level: ListViewLevel
    let selectors: [ListViewLevel : Int64]
    let groupedCells: GroupedTweakCell
    
    var body: some View {
        var newSelectors = selectors
        newSelectors[level] = groupedCells.value
        
        let cell = groupedCells.lastCollected
        let formatter = CellTechnologyFormatter.from(technology: cell.technology)
        let text = Text("\(level.extractValue(cell: cell) as NSNumber, formatter: plainNumberFormatter)")
            // Color text red if the group contains a single failed cell
            .foregroundColor(groupedCells.anyFailed ? .red : nil)
        
        return NavigationLink {
            if level == .cell {
                CellDetailsView(cell: cell)
            } else {
                LevelListView(level: level.next, selectors: newSelectors, day: Calendar.current.startOfDay(for: cell.collected!))
            }
        } label: {
            // Show status icon only on cell level
            if level == .cell {
                HStack {
                    formatter.icon()
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundColor(formatter.uiColor())
                    
                    text
                    
                    Spacer()
                }
            } else {
                text
            }
        }
    }
    
}

struct ListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CellsListView()
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}
