//
//  ListNavigationLink.swift
//  CellGuard
//
//  Created by Lukas Arnold on 30.06.25.
//

import SwiftUI

struct ListNavigationLink<P: Hashable, Label: View>: View {

    var value: P?
    var label: () -> Label

    public init(value: P?, @ViewBuilder label: @escaping () -> Label) {
      self.value = value
      self.label = label
    }

    var body: some View {
        NavigationLink(value: value, label: self.label)
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
