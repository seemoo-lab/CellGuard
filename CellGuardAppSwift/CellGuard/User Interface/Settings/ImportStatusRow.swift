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
        HStack {
            Text(text)
            Spacer()
            content
        }
    }

    var content: AnyView {
        switch status {
        case .none:
            return AnyView(EmptyView())
        case let .count(count):
            guard let count = count else {
                return AnyView(Text("\(0)"))
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
            KeyValueListRow(key: "Imported Objects", value: "\(info.count.importedCount)")
            if let total = info.count.totalCount {
                if total != info.count.importedCount {
                    Text("Some of the contained objects have already been imported before.").foregroundColor(.gray)
                }
                KeyValueListRow(key: "Total Objects", value: "\(total)")
            }
            if let firstDate = info.count.first {
                KeyValueListRow(key: "First", value: mediumDateTimeFormatter.string(from: firstDate))
            }
            if let lastDate = info.count.last {
                KeyValueListRow(key: "Last", value: mediumDateTimeFormatter.string(from: lastDate))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(info.title)
    }
}
