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

struct LabelNumberSetField: View {

    let label: String
    let hint: String
    let numberBinding: Binding<Int>

    init(_ label: String, _ hint: String, _ numberBinding: Binding<Int>) {
        self.label = label
        self.hint = hint
        self.numberBinding = numberBinding
    }

    var body: some View {
        GenericLabelField(
            label, hint, numberBinding,
            toString: { String($0) },
            fromString: {
                if let number = Int($0), number >= 0 {
                    return number
                } else {
                    return 0
                }
            }
        )
    }
}

struct GenericLabelField<T>: View {
    let label: String
    let hint: String
    let binding: Binding<T>
    let toString: (T) -> String
    let fromString: (String) -> T

    init(_ label: String, _ hint: String, _ binding: Binding<T>, toString: @escaping (T) -> String, fromString: @escaping (String) -> T) {
        self.label = label
        self.hint = hint
        self.binding = binding
        self.toString = toString
        self.fromString = fromString
    }

    var body: some View {
        HStack {
            Text(label)
            TextField(hint, text: genericBinding(binding))
                .multilineTextAlignment(.trailing)
        }
        .keyboardType(.numberPad)
        .disableAutocorrection(true)
    }

    private func genericBinding(_ property: Binding<T>) -> Binding<String> {
        // See: https://stackoverflow.com/a/65385643
        return Binding(
            get: { toString(property.wrappedValue) },
            set: { property.wrappedValue = fromString($0) }
        )
    }
}
