//
//  WelcomeSheet.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.01.23.
//

import SwiftUI

struct WelcomeSheet: View {
    
    let close: () -> Void
    
    var body: some View {
        VStack {
            ScrollView {
                Spacer()
                
                Text("Welcome to\n CellGuard")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding()
                
                WelcomeInformation(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Collect Data",
                    description: "Monitor which cells your iPhone uses to communicate with the celluar network",
                    size: 30
                )
                WelcomeInformation(
                    icon: "shield",
                    title: "Verify Connections",
                    description: "Verify that cells in use are genuine with Apple's location database",
                    size: 30
                )
                WelcomeInformation(
                    icon: "map",
                    title: "Map",
                    description: "View the location of recently connected cells on a map",
                    size: 30
                )
                
            }
            
            // The button could get a bit bigger
            LargeButton(title: "Continue", backgroundColor: .blue) {
                // Only show the introduction sheet once
                UserDefaults.standard.set(true, forKey: UserDefaultsKeys.introductionShown.rawValue)
                
                self.close()
                
                // Request permissions after the introduction sheet has been closed.
                // It's crucial that we do NOT use those manager objects as environment objects in the CompositeTabView class,
                // otherwise there are a lot of updates and shit (including toolbar stuff) breaks, e.g. NavigationView close prematurely.
                CGNotificationManager.shared.requestAuthorization { _ in
                    LocationDataManager.shared.requestAuthorization { _ in
                        CGNotificationManager.shared.requestAuthorization { _ in
                            
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        // Disable the ScrollView bounce for this element
        // https://stackoverflow.com/a/73888089
        .onAppear {
            UIScrollView.appearance().bounces = false
        }
        .onDisappear {
            UIScrollView.appearance().bounces = true
        }
    }
}

struct WelcomeInformation: View {
    
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
                .frame(maxWidth: 40, alignment: .center)
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 10))
                
            
            VStack(alignment: .leading) {
                Text(self.title)
                    .bold()
                Text(self.description)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
}

struct WelcomeSheet_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeSheet{
            // Do nothing
        }
    }
}
