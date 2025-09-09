//
//  IntroductionView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 06.06.24.
//

import SwiftUI
import NavigationBackport

struct IntroductionView: View {

    @State var path: NBNavigationPath = NBNavigationPath()

    var body: some View {
        NBNavigationStack(path: $path) {
            WelcomeView()
                .nbNavigationDestination(for: IntroductionState.self, destination: IntroductionState.navigate)
        }
    }

}

enum IntroductionState: NBScreen {
    // case welcome
    case cellDetection
    case userStudy
    case updates
    case systemDiagnose
    case location
    case notification

    var id: IntroductionState {
        self
    }

    @MainActor
    @ViewBuilder
    static func navigate(_ path: IntroductionState) -> some View {
        if path == .cellDetection {
            CellDetectionView()
        } else if path == .userStudy {
            UserStudyView { navigator in
                #if JAILBREAK
                navigator.push(IntroductionState.updates)
                #else
                navigator.push(IntroductionState.systemDiagnose)
                #endif
            }
        } else if path == .updates {
            UpdateCheckView()
        } else if path == .systemDiagnose {
            SysDiagnoseView()
        } else if path == .location {
            LocationPermissionView()
        } else if path == .notification {
            NotificationPermissionView()
        }
    }
}

#Preview {
    IntroductionView()
}
