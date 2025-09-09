//
//  DistinctStringPicker.swift
//  CellGuard
//
//  Created by mp on 09.09.25.
//

import CoreData
import SwiftUI

/// A Picker that shows distinct String values for `attribute` on entity `T`.
struct DistinctStringPicker<T: NSManagedObject>: View {
    @Binding var selection: String?           // currently selected value (optional to allow "All")
    let attribute: String                     // attribute name in Core Data (must be a String attribute)
    var title: String = "Select"
    var includeAllOption: Bool = true         // whether to show an "All" / nil option
    var allLabel: String = "All"              // label for the nil/all option
    var predicate: NSPredicate?               // optionally restrict the fetch

    @Environment(\.managedObjectContext) private var viewContext
    @State private var values: [String] = []

    var body: some View {
        Picker(title, selection: $selection) {
            if includeAllOption {
                Text(allLabel).tag(nil as String?)
            }
            ForEach(values, id: \.self) { v in
                Text(v).tag(v as String?)
            }
        }
        .onAppear(perform: loadDistinctValues)
        .onChange(of: predicate) { _ in loadDistinctValues() } // reload if predicate changes
    }

    private func loadDistinctValues() {
        // Build a fetch request that returns dictionaries with the attribute only,
        // and ask Core Data for distinct results.
        guard let entityName = T.entity().name else {
            values = []
            return
        }

        let request = NSFetchRequest<NSDictionary>(entityName: entityName)
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = [attribute]
        request.returnsDistinctResults = true
        request.predicate = predicate

        do {
            let raw = try viewContext.fetch(request)
            let strings = raw.compactMap { dict -> String? in
                // dict[attribute] might be NSNull or another type; cast to String
                return dict[attribute] as? String
            }
            // Deduplicate & sort deterministically
            let unique = Array(Set(strings)).sorted()
            values = unique
        } catch {
            print("DistinctStringPicker fetch failed:", error)
            values = []
        }
    }
}
