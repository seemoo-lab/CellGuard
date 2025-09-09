//
//  PermissionInformation.swift
//  CellGuard
//
//  Created by jiska on 20.05.24.
//

import SwiftUI
import NavigationBackport

struct CenteredTitleIconTextView: View {

    let icon: String
    let title: String?
    let description: String
    let size: CGFloat

    init(icon: String, title: String? = nil, description: String, size: CGFloat) {
        self.icon = icon
        self.title = title
        self.description = description
        self.size = size
    }

    var body: some View {
        VStack(spacing: 0) {

            // Only show the title if its set
            if let title = self.title {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                    .padding()
                    .multilineTextAlignment(.center)

                Spacer()
            }

            Image(systemName: self.icon)
                .foregroundColor(.blue)
            // We're using a fixed font size as the icons should always be the same size
            // https://sarunw.com/posts/how-to-change-swiftui-font-size/
                .font(Font.custom("SF Pro", fixedSize: self.size))
                .frame(maxWidth: 40, alignment: .center)
                .padding()

            Spacer()

            Text(self.description)
                .foregroundColor(.gray)
                .padding()
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

}

#Preview {
    NBNavigationStack {
        CenteredTitleIconTextView(
            icon: "antenna.radiowaves.left.and.right",
            description: "Why we need this permission...",
            size: 120
        )
        .navigationTitle("Name of the Permission Request")
    }

}
