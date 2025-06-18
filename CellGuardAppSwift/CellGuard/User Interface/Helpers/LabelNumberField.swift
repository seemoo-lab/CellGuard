//
//  LabelNumberField.swift
//  CellGuard
//
//  Created by Lukas Arnold on 18.06.25.
//

import SwiftUI

struct LabelNumberField: View {

    let label: String
    let hint: String
    let numberBinding: Binding<Int?>

    init(_ label: String, _ hint: String, _ numberBinding: Binding<Int?>) {
        self.label = label
        self.hint = hint
        self.numberBinding = numberBinding
    }

    var body: some View {
        HStack {
            Text(label)
            TextField(hint, text: positiveNumberBinding(numberBinding))
                .multilineTextAlignment(.trailing)
        }
        .keyboardType(.numberPad)
        .disableAutocorrection(true)
    }

    private func positiveNumberBinding(_ property: Binding<Int?>) -> Binding<String> {
        // See: https://stackoverflow.com/a/65385643
        return Binding(
            get: {
                if let number = property.wrappedValue {
                    return String(number)
                } else {
                    return ""
                }
            },
            set: {
                if let number = Int($0), number >= 0 {
                    property.wrappedValue = number
                } else {
                    property.wrappedValue = nil
                }
            }
        )
    }
}
