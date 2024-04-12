//
//  AcknowledgementView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 10.04.24.
//

import SwiftUI
import AcknowList

struct AcknowledgementView: View {
    
    @State private var acknowledgements: [Acknow] = []
    
    private func loadAcknowledgements () {
        var acknowledgements: [Acknow] = []
        
        if let url = Bundle.main.url(forResource: "Package", withExtension: "resolved"),
              let data = try? Data(contentsOf: url),
              let acknowList = try? AcknowPackageDecoder().decode(from: data) {
            acknowledgements = acknowList.acknowledgements
        } else {
            acknowledgements = []
        }
        
        if let url = Bundle.main.url(forResource: "macos-unifiedlogs-license", withExtension: "txt"),
           let data = try? Data(contentsOf: url) {
            acknowledgements.append(Acknow(
                title: "macos-unifiedlogs",
                text: String(data: data, encoding: .utf8)
            ))
        }
        
        acknowledgements.sort { $0.title < $1.title }
        self.acknowledgements = acknowledgements
    }
    
    var body: some View {
        AcknowListSwiftUIView(acknowledgements: acknowledgements)
            .onAppear {
                if (acknowledgements.isEmpty) {
                    loadAcknowledgements()
                }
            }
    }
    
}
