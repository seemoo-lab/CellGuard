//
//  CGPickerView.swift
//  CellGuard
//
//  Created by mp on 15.11.25.
//

import SwiftUI
import CoreData
import NavigationBackport

struct CGFetchPickerField<T: Identifiable & Equatable & NSManagedObject>: View {
    var title: String
    var keyPath: KeyPath<T, String?>
    var selected: Set<String>
    var onSelectChanged: (Set<String>) -> Void

    var body: some View {
        ListNavigationLink(value: FetchPickerNavigation<T>(title: title, keyPath: keyPath, selected: selected, onSelectChanged: onSelectChanged)) {
            HStack {
                Text(title)
                Spacer()
                Text("\(selected.count == 0 ? "All" : String(selected.count))")
                    .foregroundColor(.gray)
            }
        }
    }
}

struct FetchPickerNavigation<T: Identifiable & Equatable & NSManagedObject>: Hashable {
    var title: String
    var keyPath: KeyPath<T, String?>
    var selected: Set<String>
    var onSelectChanged: (Set<String>) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.keyPath == rhs.keyPath
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(keyPath)
    }
}

struct CGFetchStringPickerView<T: Identifiable & Equatable & NSManagedObject>: View {

    private var title: String
    private var keyPath: KeyPath<T, String?>
    private var selected: Set<String>
    private var onSelectChanged: (Set<String>) -> Void
    @FetchRequest private var elementsFetch: FetchedResults<T>

    init(title: String, keyPath: KeyPath<T, String?>, selected: Set<String>, onSelectChanged: @escaping (Set<String>) -> Void) {
        self.title = title
        self.keyPath = keyPath
        self.selected = selected
        self.onSelectChanged = onSelectChanged

        let fetchRequest = NSFetchRequest<T>()
        fetchRequest.entity = T.entity()
        fetchRequest.propertiesToFetch = [NSExpression(forKeyPath: keyPath).keyPath]
        fetchRequest.returnsDistinctResults = true
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: keyPath, ascending: false)]
        self._elementsFetch = FetchRequest(fetchRequest: fetchRequest, animation: .easeOut)
    }

    private func allElements() -> Set<String> {
        return Set(elementsFetch.compactMap { $0[keyPath: keyPath] })
    }

    var body: some View {
        CGStaticStringPickerView(title: title, allElements: allElements(), selectedElements: selected, onSelectChanged: onSelectChanged)
    }
}

struct CGStaticStringPickerView: View {

    private var title: String
    private var elements: Set<String>
    private var onSelectChanged: (Set<String>) -> Void

    @State private var selectedElements: Set<String> = Set()

    init(title: String, allElements: Set<String>, selectedElements: Set<String>, onSelectChanged: @escaping (Set<String>) -> Void) {
        self.title = title
        self.elements = allElements
        self.selectedElements = selectedElements
        self.onSelectChanged = onSelectChanged
    }

    private func isElementSelected(_ element: String) -> Bool {
        return selectedElements.contains(element)
    }

    private func addSelectedElement(_ element: String) {
        selectedElements.insert(element)
        onSelectChanged(selectedElements)
    }

    private func removeSelectedElement(_ element: String) {
        selectedElements.remove(element)
        onSelectChanged(selectedElements)
    }

    private func resetSelectedElements() {
        selectedElements = Set()
        onSelectChanged(selectedElements)
    }

    var body: some View {
        Group {
            if !elements.isEmpty {
                List(elements.sorted(), id: \.self) { element in
                    HStack {
                        Text(element)
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                            .opacity(isElementSelected(element) ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isElementSelected(element) {
                            removeSelectedElement(element)
                        } else {
                            addSelectedElement(element)
                        }
                    }
                }
            } else {
                Text("No elements to show.")
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem {
                Button {
                    resetSelectedElements()
                } label: {
                    Text("Reset")
                }
            }
        }
    }
}
