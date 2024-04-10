//
//  AcknowledgementView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 10.04.24.
//

import SwiftUI
import AcknowList

struct AcknowledgementView: View {
    
    private let acknowledgements: [Acknow]
    
    init() {
        
        if let url = Bundle.main.url(forResource: "Package", withExtension: "resolved"),
              let data = try? Data(contentsOf: url),
              let acknowList = try? AcknowPackageDecoder().decode(from: data) {
            acknowledgements = acknowList.acknowledgements
        } else {
            acknowledgements = []
        }
    }
    
    var body: some View {
        AcknowListSwiftUIView(acknowledgements: acknowledgements)
    }
    
}
