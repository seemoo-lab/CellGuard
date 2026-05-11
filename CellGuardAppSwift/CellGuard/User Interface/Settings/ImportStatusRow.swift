//
//  ImportStatusRow.swift
//  CellGuard
//
//  Created by Lukas Arnold on 28.08.25.
//

import SwiftUI

struct ImportStatusRow: View {
    let text: String
    @Binding var status: ImportStatus

    init(_ text: String, _ status: Binding<ImportStatus>) {
        self.text = text
        self._status = status
    }

    var body: some View {
        if case .count(value: let count) = self.status,
           let count = count,
           count.first != nil || count.last != nil || (count.totalCount != nil && count.totalCount != count.importedCount) {
            ListNavigationLink(value: CountInfo(title: text, count: count)) {
                row
            }
        } else {
            row
        }
    }

    var row: some View {
        KeyValueListRow(key: text) {
            content
        }
    }

    var content: AnyView {
        switch status {
        case .none:
            return AnyView(EmptyView())
        case let .count(count):
            guard let count = count else {
                return AnyView(Text("0"))
            }
            if let total = count.totalCount {
                let text = count.importedCount == total ? "\(count.importedCount)" : "\(count.importedCount) / \(total)"
                return AnyView(Text(text))
            } else {
                return AnyView(Text("\(count.importedCount)"))
            }
        case .progress:
            return AnyView(CircularProgressView(progress: $status.progress)
                .frame(width: 20, height: 20))
        case .infinite:
            return AnyView(ProgressView())
        case .error:
            return AnyView(Image(systemName: "xmark").foregroundColor(.gray))
        case .finished:
            return AnyView(Image(systemName: "checkmark").foregroundColor(.gray))
        }
    }
}

struct CountInfo: Hashable {
    let title: String
    let count: ImportCount
}

struct ImportStatusDetailsView: View {
    let info: CountInfo

    var body: some View {
        List {
            if let total = info.count.totalCount {
                ImportedAndTotalView(info: info, total: total)
            } else {
                ImportedOnlyView(info: info)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(info.title)
    }
}

private struct ImportedAndTotalView: View {
    let imported: Int
    let total: Int
    let firstDate: Date?
    let lastDate: Date?
    let title: String

    init(info: CountInfo, total: Int) {
        self.imported = info.count.importedCount
        self.total = total
        self.firstDate = info.count.first
        self.lastDate = info.count.last
        self.title = info.title
    }

    var body: some View {
        Group {
            Section {
                DetailsRow("\(title)", imported)
            } header: {
                Text("Imported")
            } footer: {
                if total != imported {
                    Text("Some of the objects already were imported before.")
                }
            }
            Section {
                DetailsRow("\(title)", total)
                if let firstDate = firstDate {
                    KeyValueListRow(key: "First", value: mediumDateTimeFormatter.string(from: firstDate))
                }
                if let lastDate = lastDate {
                    KeyValueListRow(key: "Last", value: mediumDateTimeFormatter.string(from: lastDate))
                }
            } header: {
                Text("Available")
            }
        }
    }
}

private struct ImportedOnlyView: View {
    let imported: Int
    let firstDate: Date?
    let lastDate: Date?
    let title: String

    init(info: CountInfo) {
        self.imported = info.count.importedCount
        self.firstDate = info.count.first
        self.lastDate = info.count.last
        self.title = info.title
    }

    var body: some View {
        Group {
            Section {
                DetailsRow("\(title)", imported)
                if let firstDate = firstDate {
                    KeyValueListRow(key: "First", value: mediumDateTimeFormatter.string(from: firstDate))
                }
                if let lastDate = lastDate {
                    KeyValueListRow(key: "Last", value: mediumDateTimeFormatter.string(from: lastDate))
                }
            } header: {
                Text("Imported")
            }
        }
    }
}
