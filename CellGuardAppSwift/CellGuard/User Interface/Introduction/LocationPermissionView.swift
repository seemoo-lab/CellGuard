//
//  LocationPermissionView.swift
//  CellGuard
//
//  Created by jiska on 20.05.24.
//

import SwiftUI
import NavigationBackport

struct LocationPermissionView: View {

    @EnvironmentObject var navigator: PathNavigator

    var body: some View {
        VStack {
            ScrollView {
                CenteredTitleIconTextView(
                    icon: "location.fill",
                    description: "CellGuard records when and where your phone is connected to a cell tower. This information is compared with a cell location database, uncovering unknown base stations.\n\nCellGuard keeps location information for seven days. You can adjust this value in the settings.",
                    size: 120
                )
            }

            LargeButton(title: "Continue", backgroundColor: .blue) {
                // Request permissions after the introduction sheet has been closed.
                // It's crucial that we do NOT use those manager objects as environment objects in the CompositeTabView class,
                // otherwise there are a lot of updates and shit (including toolbar stuff) breaks, e.g. NavigationView close prematurely.
                LocationDataManager.shared.requestAuthorization { success in

                    // Enable the data collection (depending on the app type) if the user shares their location with CellGuard
                    if success {
                        #if JAILBREAK
                        UserDefaults.standard.setValue(DataCollectionMode.automatic.rawValue, forKey: UserDefaultsKeys.appMode.rawValue)
                        #else
                        UserDefaults.standard.setValue(DataCollectionMode.manual.rawValue, forKey: UserDefaultsKeys.appMode.rawValue)
                        #endif
                    }

                    next()
                }
            }
            .padding()
        }
        .navigationTitle("Location Permission")
        .toolbar {
            ToolbarItem {
                Button("Skip") {
                    next()
                }
            }
        }
    }

    func next() {
        navigator.push(IntroductionState.notification)
    }
}

#Preview {
    NavigationView {
        LocationPermissionView()
    }
}
