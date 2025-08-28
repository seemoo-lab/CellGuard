//
//  ListNavigationButton.swift
//  CellGuard
//
//  Created by Lukas Arnold on 27.08.25.
//

import SwiftUI

struct ListNavigationButton<Label: View>: View {

    @Environment(\.isEnabled) private var isEnabled

    var action: () -> Void
    var label: Label

    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: self.action) {
            HStack {
                label
                    .foregroundColor(.primary.opacity(isEnabled ? 1 : 0.5))
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray.opacity(isEnabled ? 0.6 : 0.3))
                    .imageScale(.small)
            }
        }
    }
}
