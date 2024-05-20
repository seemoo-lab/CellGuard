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
                        description: """
CellGuard detects suspicious network cell behavior based on management information exchanged when connecting to base stations.

Note that CellGuard senses anomalies that, in most cases, originate from legitimate network setups. For example, if your cellular network provider's coverage is low, your iPhone might connect to third-party networks. CellGuard also detects new cells added to a network, usually resulting from a change by an authorized service provider.

In a few cases, these anomalies indicate an attack by a fake base station. Such an attack could lead to tracking of your iPhone's location, network traffic interception and manipulation, and enable attackers to launch remote code execution attacks on the baseband chip.
""",
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
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CellDetectionView_Provider: PreviewProvider {
    static var previews: some View {
        CellDetectionView{}
    }
}
