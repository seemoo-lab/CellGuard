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
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance

        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }

    static func transparent() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance

        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }

}
