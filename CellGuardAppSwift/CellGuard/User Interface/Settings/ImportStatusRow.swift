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
            let count = count, count.first != nil, count.last != nil {
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
            return AnyView(Text("\(count?.count ?? 0)"))
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
            KeyValueListRow(key: "Imported Entries", value: "\(info.count.count)")
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
