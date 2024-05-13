//
//  RiskInfoView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 13.05.24.
//

import SwiftUI

struct RiskInfoView: View {
    
    let risk: RiskLevel
    
    var body: some View {
        ScrollView {
            
            Text("CellGuard uses a detection algorithm to rate all cells your iPhone connects to...")
            
            // TODO: @Jiska add explanations of the app's function and the user's risk (based on the risk level).
            // Be aware that the terms (of risk levels & cell categories) displayed to the user and used in the code differ.
            // See RiskIndicatorCard.swift for more information.
            
            // Some more ideas for this view: https://dev.seemoo.tu-darmstadt.de/apple/cell-guard/-/issues/66
            // Maybe you could also use a SwiftUI List to display the information, be creative :)
            
            // TODO: Add a button linking to the RiskInfoCellListView
        }
        .padding()
        .navigationTitle("Detection Results")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RiskInfoCellListView: View {
    
    var body: some View {
        // TODO: @Lukas list all cells which are anomalous or suspicious
        List {
            Text("Didn't rate any cells as anomalous or suspicious cells so far.")
        }
    }
    
}

#Preview {
    NavigationView {
        RiskInfoView(risk: .Medium(cause: .Cells(cellCount: 3)))
    }
}

