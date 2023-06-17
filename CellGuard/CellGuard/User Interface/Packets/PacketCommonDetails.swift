//
//  CommonPacketDetailsView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 09.06.23.
//

import Foundation
import SwiftUI

struct PacketDetailsRow: View {
    
    let description: String
    let value: String
    
    init(_ description: String, _ value: String) {
        self.description = description
        self.value = value
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
    
    var body: some View {
        KeyValueListRow(key: description, value: value)
    }
}

struct PacketDetailsDataRow: View {
    
    let description: String
    let hexString: String
    
    init(_ description: String, data: Data) {
        self.description = description
        self.hexString = data
            .map { String($0, radix: 16, uppercase: true) }
            .map { $0.count < 2 ? "0\($0)" : $0 }
            .joined(separator: " ")
    }
    
    var body: some View {
        VStack {
            HStack {
                Text(description)
                Spacer()
            }
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0))
            HStack {
                Text(hexString)
                    .font(Font(UIFont.monospacedSystemFont(ofSize: UIFont.systemFontSize, weight: .regular)))
                Spacer()
            }
        }
    }
}
