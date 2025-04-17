//
//  NotificationPermissionView.swift
//  CellGuard
//
//  Created by jiska on 19.05.24.
//

import SwiftUI

struct NotificationPermissionView: View {

    var body: some View {
        VStack {
            ScrollView {
                CenteredTitleIconTextView(
                    icon: "bell.fill",
                    description: "CellGuard continues the cell analysis in the background. To receive alerts about cellular network anomalies, you can allow CellGuard to send notifications.",
                    size: 120
                )
            }

            LargeButton(title: "Continue", backgroundColor: .blue) {
                // Request permissions after the introduction sheet has been closed.
                // It's crucial that we do NOT use those manager objects as environment objects in the CompositeTabView class,
                // otherwise there are a lot of updates and shit (including toolbar stuff) breaks, e.g. NavigationView close prematurely.

                CGNotificationManager.shared.requestAuthorization { _ in
                    // Save that we did show the intro (only once we receive a result for the notification permission)
                    UserDefaults.standard.set(true, forKey: UserDefaultsKeys.introductionShown.rawValue)
                }
            }
            .padding()
        }
        .navigationTitle("Notification Permission")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(content: {
            ToolbarItem {
                Button("Skip") {
                    UserDefaults.standard.set(true, forKey: UserDefaultsKeys.introductionShown.rawValue)
                }
            }
        })
    }
}

#Preview {
    NavigationView {
        NotificationPermissionView()
    }
}
