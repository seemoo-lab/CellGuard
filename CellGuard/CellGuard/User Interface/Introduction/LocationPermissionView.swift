//
//  LocationPermissionView.swift
//  CellGuard
//
//  Created by jiska on 20.05.24.
//

import SwiftUI

struct LocationPermissionView: View {
    
    @State private var action: Int? = 0

    var body: some View {
        VStack {
            ScrollView {
                CenteredTitleIconTextView(
                    icon: "location.fill",
                    description: "CellGuard records when and where your phone is connected to a cell tower. This information is compared with a cell location database, uncovering unknown base stations.\n\nCellGuard keeps location information for seven days. You can adjust this value in the settings.",
                    size: 120
                )
            }
            
            // Navigate to next permission, forward closing statement
            NavigationLink(destination: NotificationPermissionView(), tag: 1, selection: $action) {}
            
            LargeButton(title: "Continue", backgroundColor: .blue) {
                // Request permissions after the introduction sheet has been closed.
                // It's crucial that we do NOT use those manager objects as environment objects in the CompositeTabView class,
                // otherwise there are a lot of updates and shit (including toolbar stuff) breaks, e.g. NavigationView close prematurely.
                LocationDataManager.shared.requestAuthorization { _ in
                    // Enable the data collection (depending on the app type)
                    #if JAILBREAK
                    UserDefaults.standard.setValue(DataCollectionMode.automatic.rawValue, forKey: UserDefaultsKeys.appMode.rawValue)
                    #else
                    UserDefaults.standard.setValue(DataCollectionMode.manual.rawValue, forKey: UserDefaultsKeys.appMode.rawValue)
                    #endif
                    
                    self.action = 1
                }
            }
            .padding()
        }
        .navigationTitle("Location Permission")
        .toolbar(content: {
            ToolbarItem {
                Button("Skip") {
                    self.action = 1
                }
            }
        })

    }
}

#Preview {
    NavigationView {
        LocationPermissionView()
    }
}
