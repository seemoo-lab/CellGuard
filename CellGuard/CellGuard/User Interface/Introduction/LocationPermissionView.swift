//
//  LocationPermissionView.swift
//  CellGuard
//
//  Created by jiska on 20.05.24.
//

import SwiftUI

struct LocationPermissionView: View {
    
    @State private var action: Int? = 0
    let close: () -> Void

    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    PermissionInformation(
                        icon: "location.fill",
                        title: "Location Permission",
                        description: "CellGuard records when and where your phone is connected to a cell tower. This information is compared with a cell location database, uncovering unknown base stations.\n\nCellGuard keeps location information for seven days. You can adjust this value in the settings.",
                        size: 120
                    )
                }
                
                // Navigate to next permission, forward closing statement
                NavigationLink(destination: NotificationPermissionView{self.close()}, tag: 1, selection: $action) {}
                
                LargeButton(title: "Continue", backgroundColor: .blue) {
                    // Request permissions after the introduction sheet has been closed.
                    // It's crucial that we do NOT use those manager objects as environment objects in the CompositeTabView class,
                    // otherwise there are a lot of updates and shit (including toolbar stuff) breaks, e.g. NavigationView close prematurely.
                    LocationDataManager.shared.requestAuthorization { _ in}
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

struct LocationPermissionView_Preview: PreviewProvider {
    static var previews: some View {
        LocationPermissionView{}
    }
}
