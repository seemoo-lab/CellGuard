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
    /// Currently selected value (optional to allow "All")
    @Binding var selection: String?

    /// Attribute key path of the Core Data object (for type checking)
    let attribute: ReferenceWritableKeyPath<T, String?>
    /// Attribute name in Core Data (should be similar to attribute, must be a String attribute)
    /// Unfortunately Core Data does not support key path objects for restricting properties to fetch
    /// and key path objects do not retrain the original property name.
    let attributeName: String
    /// Optionally restrict the fetch operation with a predicate
    var predicate: NSPredicate?

    /// The label of the picker
    var title: String = "Select"
    /// Whether to show an "All" / nil option
    var includeAllOption: Bool = true
    /// Label for the "All" / nil option
    var allLabel: String = "All"

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
        // reload if predicate changes
        .onChange(of: predicate) { _ in loadDistinctValues() }
    }

    private func loadDistinctValues() {
        // Build a fetch request that returns dictionaries with the attribute only,
        // and ask Core Data for distinct results.
        guard let entityName = T.entity().name else {
            values = []
            return
        }

        let request = NSFetchRequest<T>(entityName: entityName)
        request.propertiesToFetch = [attributeName]
        request.returnsDistinctResults = true
        request.predicate = predicate

        do {
            let objects = try viewContext.fetch(request)
            let strings = objects.compactMap { object -> String? in
                return object[keyPath: attribute]
            }
            // Deduplicate & sort deterministically
            let unique = Array(Set(strings)).sorted()
            values = unique
        } catch {
            print("DistinctStringPicker fetch failed: ", error)
            values = []
        }
    }
}
