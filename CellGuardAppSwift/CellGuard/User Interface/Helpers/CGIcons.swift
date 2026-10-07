//
//  CGIcons.swift
//  CellGuard
//
//  Created by Lukas Arnold on 10.09.25.
//

import Foundation

struct CGIcons {

    static var filter: String {
        if #available(iOS 26, *) {
            "line.3.horizontal.decrease"
        } else {
            "line.3.horizontal.decrease.circle"
        }
    }

    static var settings: String {
        if #available(iOS 26, *) {
            "ellipsis"
        } else {
            "ellipsis.circle"
        }
    }

}
