//
//  DetailsRow.swift
//  CellGuard
//
//  Created by mp on 30.08.25.
//

import SwiftUI

struct DetailsRow: View {

    let description: String
    let icon: String?
    let color: Color?
    let value: String
    let multiLine: Bool
    var font: Font?

    init(_ description: String, _ value: Int) {
        self.init(description, value as NSNumber)
    }

    init(_ description: String, _ value: Int32) {
        self.init(description, value as NSNumber)
    }

    init(_ description: String, _ value: Int64) {
        self.init(description, value as NSNumber)
    }

    init(_ description: String, _ value: NSNumber) {
        self.init(description, plainNumberFormatter.string(from: value) ?? "-")
    }

    init(_ description: String, hex: UInt8) {
        self.init(description, hex: hex, min: 2)
    }

    init(_ description: String, hex: UInt16) {
        self.init(description, hex: hex, min: 4)
    }

    init(_ description: String, hex: any BinaryInteger, min: Int) {
        var str = String(hex, radix: 16, uppercase: true)
        if str.count < min {
            str = String(repeating: "0", count: min - str.count) + str
        }
        self.init(description, "0x\(str)")
    }

    init(_ description: String, bytes: Int) {
        self.init(description, "\(bytes)\u{2009} Byte")
    }

    init(_ description: String, bool: Bool) {
        self.init(description, bool ? "true" : "false")
    }

    init(_ description: String, date: Date?) {
        if let date = date {
            self.init(description, "\(fullMediumDateTimeFormatter.string(from: date))")
        } else {
            self.init(description, "???")
        }
    }

    init(_ description: String, data: Data) {
        self.init(description, data
            .map { String($0, radix: 16, uppercase: true) }
            .map { $0.count < 2 ? "0\($0)" : $0 }
            .joined(separator: " "), multiLine: true)
        self.font = Font(UIFont.monospacedSystemFont(ofSize: UIFont.systemFontSize, weight: .regular))
    }

    init(_ description: String, _ value: String, icon: String? = nil, color: Color? = .gray, multiLine: Bool = false) {
        self.description = description
        self.value = value
        self.icon = icon
        self.color = color
        self.multiLine = multiLine
    }

    var body: some View {
        let content = Group {
            HStack {
                Text(value)
                    .font(font)
                if multiLine {
                    Spacer()
                }
                if let icon = self.icon {
                    Image(systemName: icon)
                }
            }
            .if(color != nil) { view in
                view.foregroundColor(color)
            }
        }

        if multiLine {
            VStack {
                HStack {
                    Text(description)
                    Spacer()
                }
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0))
                content
            }
        } else {
            KeyValueListRow(key: description) {
                content
            }
        }
    }

}
