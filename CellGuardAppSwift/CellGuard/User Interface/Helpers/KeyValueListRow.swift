//
//  KeyValueListRow.swift
//  CellGuard
//
//  Created by Lukas Arnold on 17.06.23.
//

import SwiftUI

struct KeyValueListRow<Content: View>: View {
    let key: String
    @ViewBuilder var value: () -> Content

    init(key: String, value: String) where Content == Text {
        // See: https://stackoverflow.com/a/70554732
        self.key = key
        self.value = {
            Text(value)
        }
    }

    init(key: String, value: @escaping () -> Content) {
        self.key = key
        self.value = value
    }

    var body: some View {
        HStack {
            Text(key)
                .multilineTextAlignment(.leading)
            Spacer()
            value()
                .foregroundColor(.gray)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct KeyValueListRow_Previews: PreviewProvider {
    static var previews: some View {
        List {
            KeyValueListRow(key: "Hello", value: "Test")
            KeyValueListRow(key: "Hello") {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Test")
                }
            }
        }
    }
}
