//
//  IosUnifiedLogsApp.swift
//  IosUnifiedLogs
//
//  Created by Lukas Arnold on 28.07.23.
//

import SwiftUI

@main
struct IosUnifiedLogsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(RustAppWrapper(rust: RustApp()))
        }
    }
}

class RustAppWrapper: ObservableObject {
    var rust: RustApp
    
    init (rust: RustApp) {
        self.rust = rust
    }
}
