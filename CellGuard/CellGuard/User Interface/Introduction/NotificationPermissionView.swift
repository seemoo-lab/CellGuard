//
//  NotificationPermissionView.swift
//  CellGuard
//
//  Created by jiska on 19.05.24.
//

import SwiftUI


struct NotificationPermissionView: View {
    
    let close: () -> Void

    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    PermissionInformation(
                        icon: "bell.fill",
                        title: "Notification Permission",
                        description: "CellGuard continues cell analysis in background. To be informed about cellular network anomalities, you need to enable notifications for CellGuard.",
                        size: 120
                    )
                }
                
                
                LargeButton(title: "Continue", backgroundColor: .blue) {
                    // Save that we did show the intro (only on last tab due to permissions!)
                    UserDefaults.standard.set(true, forKey: UserDefaultsKeys.introductionShown.rawValue)
                    // Request permissions after the introduction sheet has been closed.
                    // It's crucial that we do NOT use those manager objects as environment objects in the CompositeTabView class,
                    // otherwise there are a lot of updates and shit (including toolbar stuff) breaks, e.g. NavigationView close prematurely.
                    CGNotificationManager.shared.requestAuthorization { _ in}
                    self.close()  // end of introduction, close to return to CompositeTabView
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

struct NotificationPermissionView_Preview: PreviewProvider {
    static var previews: some View {
        NotificationPermissionView{}
    }
}

