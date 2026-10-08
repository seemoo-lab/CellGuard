//
//  LargeButton.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.01.23.
//

import SwiftUI

struct LargeButton: View {

    var backgroundColor: Color
    var foregroundColor: Color

    private let title: String
    private let action: () -> Void

    private let disabled: Bool

    init(title: String,
         disabled: Bool = false,
         backgroundColor: Color = Color.green,
         foregroundColor: Color = Color.white,
         action: @escaping () -> Void) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.title = title
        self.action = action
        self.disabled = disabled
    }

    var body: some View {
        HStack {
            Spacer(minLength: 10)
            Button(action: self.action) {
                Text(self.title)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(foregroundColor)
            }
            .buttonStyle(.borderedProminent)
            .tint(backgroundColor)
            .controlSize(.large)
            .buttonBorderShape(.roundedRectangle(radius: 12))
            .font(.system(size: 19, weight: .semibold))
            .padding(.vertical, 10)
            .disabled(self.disabled)
            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity)
    }

}

struct LargeButtonLink<P: Hashable>: View {

    var backgroundColor: Color
    var foregroundColor: Color

    private let title: String
    private let value: P

    private let disabled: Bool

    init(title: String,
         value: P,
         disabled: Bool = false,
         backgroundColor: Color = Color.green,
         foregroundColor: Color = Color.white) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.title = title
        self.value = value
        self.disabled = disabled
    }

    var body: some View {
        HStack {
            Spacer(minLength: 10)
            NavigationLink(value: value) {
                Text(self.title)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(foregroundColor)
            }
            .buttonStyle(.borderedProminent)
            .tint(backgroundColor)
            .controlSize(.large)
            .buttonBorderShape(.roundedRectangle(radius: 12))
            .font(.system(size: 19, weight: .semibold))
            .padding(.vertical, 10)
            .disabled(self.disabled)
            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LargeButton_Previews: PreviewProvider {
    static var previews: some View {
        LargeButton(title: "Hello") {
            // Doing nothing
        }
    }
}
