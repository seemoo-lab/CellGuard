//
//  BackgroundState.swift
//  CellGuard
//
//  Created by Lukas Arnold on 16.01.23.
//

import Foundation
import SwiftUI
import OSLog

class BackgroundState: ObservableObject {
    
    static let shared = BackgroundState()
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: BackgroundState.self)
    )
    
    @Published var inBackground = false
    
    private init() {
        
    }
    
    func update(from phase: ScenePhase) {
        self.inBackground = phase != .active
        Self.logger.debug("Scene Phase Update: \(String(describing: phase)) -> inBackground = \(self.inBackground)")
    }
    
}
