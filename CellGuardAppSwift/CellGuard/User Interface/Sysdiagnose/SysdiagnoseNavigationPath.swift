//
//  SysdiagnoseNavigationPath.swift
//  CellGuard
//
//  Created by Lukas Arnold on 28.08.25.
//

import SwiftUI
import NavigationBackport

enum SysdiagnoseNavigationPath: NBScreen {

    case filterFilenames

    @MainActor
    @ViewBuilder
    static func navigate(_ path: SysdiagnoseNavigationPath) -> some View {
        if path == .filterFilenames {
            SysdiagnoseFilterFilenameView()
        } else {
            Text("Missing navigation path: \(String(describing: path))")
        }
    }

    var id: SysdiagnoseNavigationPath {
        self
    }

}
