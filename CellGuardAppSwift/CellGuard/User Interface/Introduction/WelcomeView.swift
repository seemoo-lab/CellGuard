//
//  WelcomeSheet.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.01.23.
//

import SwiftUI
import NavigationBackport

struct WelcomeView: View {

    var body: some View {
        VStack {
            ScrollView {
                (Text("Welcome to \n") + Text("CellGuard").foregroundColor(.blue))
                    .font(.system(size: 35, weight: .heavy))
                    .padding(EdgeInsets(top: 30, leading: 5, bottom: 20, trailing: 5))
                    .multilineTextAlignment(.center)
                WelcomeInformation(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Analyze Cellular Network",
                    description: "Monitor which cells your iPhone uses to communicate with the cellular network.",
                    size: 35
                )
                WelcomeInformation(
                    icon: "shield",
                    title: "Verify Cells",
                    description: "Detect and report suspicious behavior of connected cells.",
                    size: 35
                )
                WelcomeInformation(
                    icon: "map",
                    title: "Map Cells",
                    description: "View the location of recently connected cells on a map.",
                    size: 35
                )
            }

            LargeButtonLink(title: "Continue", value: IntroductionState.cellDetection, backgroundColor: .blue)
                .padding()
        }
        .navigationTitle("Welcome to CellGuard")
        .navigationBarHidden(true)
        // .navigationBarTitleDisplayMode(.large)
    }
}

private struct WelcomeInformation: View {

    let icon: String
    let title: String
    let description: String
    let size: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: self.icon)
                .foregroundColor(.blue)
                // We're using a fixed font size as the icons should always be the same size
                // https://sarunw.com/posts/how-to-change-swiftui-font-size/
                .font(Font.custom("SF Pro", fixedSize: self.size))
                .frame(width: 50)
                .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 15))

            VStack(alignment: .leading) {
                Text(self.title)
                    .bold()
                    .padding(1)
                Text(self.description)
                    .foregroundColor(.gray)
                    .padding(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

}

#Preview {
    NBNavigationStack {
        WelcomeView()
            .nbNavigationDestination(for: IntroductionState.self) { _ in
                Text("No")
            }
    }
}
