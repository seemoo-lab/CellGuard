//
//  Preview.swift
//  CellGuard
//
//  Created by Lukas Arnold on 22.07.23.
//

import Foundation

struct PreviewInfo {

    static func active() -> Bool {
        // See: https://stackoverflow.com/a/61741858
        #if targetEnvironment(simulator)
            return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        #else
            return false
        #endif
    }

}
