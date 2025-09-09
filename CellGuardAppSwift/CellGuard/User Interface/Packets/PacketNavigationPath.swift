//
//  PacketNavigationPath.swift
//  CellGuard
//
//  Created by Lukas Arnold on 28.08.25.
//

import SwiftUI
import NavigationBackport

enum PacketNavigationPath: NBScreen {

    case filter
    case filterGroupsAri
    case filterServicesQmi

    @MainActor
    @ViewBuilder
    static func navigate(_ path: PacketNavigationPath) -> some View {
        if path == .filter {
            PacketFilterListView()
        } else if path == .filterGroupsAri {
            PacketFilterARIGroupsView()
        } else if path == .filterServicesQmi {
            PacketFilterQMIServicesView()
        } else {
            Text("Missing navigation path: \(String(describing: path))")
        }
    }

    var id: PacketNavigationPath {
        self
    }

}
