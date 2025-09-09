//
//  LargeButton.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.01.23.
//

import SwiftUI
import NavigationBackport

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

private struct LargeButtonProperties {
    static let buttonHorizontalMargins: CGFloat = 10
}

struct LargeButton: View {

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
            Spacer(minLength: LargeButtonProperties.buttonHorizontalMargins)
            Button(action: self.action) {
                Text(self.title)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LargeButtonStyle(backgroundColor: backgroundColor,
                                          foregroundColor: foregroundColor,
                                          isDisabled: disabled))
            .disabled(self.disabled)
            Spacer(minLength: LargeButtonProperties.buttonHorizontalMargins)
        }
        .frame(maxWidth: .infinity)
    }

}

struct LargeButtonLink<P: Hashable>: View {

    var backgroundColor: Color
    var foregroundColor: Color

    private let title: String
    private let value: P

    // It would be nice to make this into a binding.
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
            Spacer(minLength: LargeButtonProperties.buttonHorizontalMargins)
            NBNavigationLink(value: value) {
                Text(self.title)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LargeButtonStyle(backgroundColor: backgroundColor,
                                          foregroundColor: foregroundColor,
                                          isDisabled: disabled))
            .disabled(self.disabled)
            Spacer(minLength: LargeButtonProperties.buttonHorizontalMargins)
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
