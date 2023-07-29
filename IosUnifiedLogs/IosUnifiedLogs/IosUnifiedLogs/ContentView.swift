//
//  ContentView.swift
//  IosUnifiedLogs
//
//  Created by Lukas Arnold on 28.07.23.
//

import SwiftUI
import SWCompression
import Gzip

enum DecodingState {
    case waitingForFile
    case unarchiving
    case extractingTar
    case readingLogs
    case finished
}

struct ContentView: View {
    @EnvironmentObject var rustApp: RustAppWrapper
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
            Text(rustApp.rust.generate_html().toString())
        }
        .padding()
        .onOpenURL { url in
            print("Hey, new URL just dropped: \(url)")
            Task(priority: .medium) {
                LogArchiveReader().read(url: url, rust: rustApp.rust)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
