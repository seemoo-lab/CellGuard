//
//  TestDetection.swift
//  CellGuard
//
//  Created by Lukas Arnold on 19.01.23.
//

import Foundation

// https://stackoverflow.com/a/29991529

let isTestRun = {
    #if DEBUG
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
        return true
    }
    #endif

    return false
}()
