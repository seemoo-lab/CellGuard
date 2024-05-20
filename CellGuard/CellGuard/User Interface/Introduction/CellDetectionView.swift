//
//  CellDetectionView.swift
//  CellGuard
//
//  Created by jiska on 20.05.24.
//

import SwiftUI

struct CellDetectionView: View {
    
    @State private var action: Int? = 0
    let close: () -> Void

    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    PermissionInformation(
                        icon: "cellularbars",
                        title: "Fake Base Stations",
                        description: "CellGuard detects suspicious network cell behavior based on management information exchanged when connecting to base stations.\n\nNote that your iPhone might connect to cells categorized as suspicious during everyday usage. For example, if your provider's network coverage is low, your iPhone might connect to other service providers.",
                        size: 120
                    )
                
                }
                

                NavigationLink(destination: UserStudyView{self.close()}, tag: 1, selection: $action) {}

                
                LargeButton(title: "Continue", backgroundColor: .blue) {
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
        }.navigationBarBackButtonHidden(true)
    }
}

struct CellDetectionView_Provider: PreviewProvider {
    static var previews: some View {
        CellDetectionView{}
    }
}
