//
//  ListNavigationLink.swift
//  CellGuard
//
//  Created by Lukas Arnold on 30.06.25.
//

import SwiftUI
import NavigationBackport

struct ListNavigationLink<P: Hashable, Label: View>: View {

    @Environment(\.isEnabled) private var isEnabled

    var value: P?
    var label: Label

    public init(value: P?, @ViewBuilder label: @escaping () -> Label) {
      self.value = value
      self.label = label()
    }

    var body: some View {
        // We can't simply use a button style, because its background doesn't fill the whole button
        NBNavigationLink(value: value) {
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

extension ListNavigationLink where Label == Text {
  init(_ titleKey: LocalizedStringKey, value: P?) {
    self.init(value: value) { Text(titleKey) }
  }

  init<S>(_ title: S, value: P?) where S: StringProtocol {
    self.init(value: value) { Text(title) }
  }
}
