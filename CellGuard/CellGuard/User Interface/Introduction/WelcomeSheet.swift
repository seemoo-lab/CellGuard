//
//  WelcomeSheet.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.01.23.
//

import SwiftUI

struct WelcomeSheet: View {
    
    //let close: () -> Void
    @State private var action: Int? = 0
    let close: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    
                    Text("Welcome to\n CellGuard")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding()
                    
                    WelcomeInformation(
                        icon: "antenna.radiowaves.left.and.right",
                        title: "Collect Cellular Network Data",
                        description: "Monitor which cells your iPhone uses to communicate with the cellular network.",
                        size: 35
                    )
                    WelcomeInformation(
                        icon: "shield",
                        title: "Verify Cells",
                        description: "Verify that cells in use are secure and detect suspicious behavior.",
                        size: 35
                    )
                    WelcomeInformation(
                        icon: "map",
                        title: "Map",
                        description: "View the location of recently connected cells on a map.",
                        size: 35
                    )
                    
                }
                

                
                // Navigate to next permission, forward closing statement
                // WelcomeSheet
                //  -> CellDetectionView
                //  -> UserStudyView
                //  -> SysDiagnoseView (non-jailbroken)
                //  -> LocationPermissionView
                //  -> NotificationPermissionView
                NavigationLink(destination: CellDetectionView{self.close()}, tag: 1, selection: $action) {}
                
                LargeButton(title: "Continue", backgroundColor: .blue) {
                    
                    // Set data collection mode to manual if compiled for non-jailbroken
                    #if JAILBREAK
                    #else
                    UserDefaults.standard.set("manual", forKey: UserDefaultsKeys.appMode.rawValue)
                    #endif
                    
                    self.action = 1
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
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .navigationBarTitleDisplayMode(.inline)
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

struct WelcomeSheet_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeSheet{}
    }
}
