//
//  CGTabBarAppearance.swift
//  CellGuard
//
//  Created by Lukas Arnold on 31.01.23.
//

import UIKit

struct CGTabBarAppearance {

    // See: https://nemecek.be/blog/127/how-to-disable-automatic-transparent-tabbar-in-ios-15

    static func opaque() {
        // The following attributes only have an effect on non-Liquid-Glass iOS versions
        guard #unavailable(iOS 26) else { return }

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }

}
