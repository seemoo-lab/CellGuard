//
//  LargeButton.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.01.23.
//

import SwiftUI

// The button properties .buttonStyle(.bordered) and .tint(.primary) are only available in iOS 15.
// Therefore we're using an external class to match Apple's button style.
// Source: https://stackoverflow.com/a/62544642

struct LargeButtonStyle: ButtonStyle {

    private static let cornerRadius: CGFloat = 12

    let backgroundColor: Color
    let foregroundColor: Color
    let isDisabled: Bool

    func makeBody(configuration: Self.Configuration) -> some View {
        let currentForegroundColor = isDisabled || configuration.isPressed ? foregroundColor.opacity(0.3) : foregroundColor
        return configuration.label
            .padding()
            .foregroundColor(currentForegroundColor)
            .background(isDisabled || configuration.isPressed ? backgroundColor.opacity(0.3) : backgroundColor)
        // This is the key part, we are using both an overlay as well as cornerRadius
            .cornerRadius(Self.cornerRadius)
        // Disable the overlay because it looks bad when dark mode is enabled
            /* .overlay(
                RoundedRectangle(cornerRadius: Self.cornerRadius)
                    .stroke(currentForegroundColor, lineWidth: 1)
            ) */
            .padding([.top, .bottom], 10)
            .font(Font.system(size: 19, weight: .semibold))
    }
}

struct LargeButton: View {

    private static let buttonHorizontalMargins: CGFloat = 10

    var backgroundColor: Color
    var foregroundColor: Color

    private let title: String
    private let action: () -> Void

    // It would be nice to make this into a binding.
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
            Spacer(minLength: LargeButton.buttonHorizontalMargins)
            Button(action: self.action) {
                Text(self.title)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LargeButtonStyle(backgroundColor: backgroundColor,
                                          foregroundColor: foregroundColor,
                                          isDisabled: disabled))
            .disabled(self.disabled)
            Spacer(minLength: LargeButton.buttonHorizontalMargins)
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
