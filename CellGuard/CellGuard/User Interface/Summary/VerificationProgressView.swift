//
//  ScanProgressSheet.swift
//  CellGuard
//
//  Created by Lukas Arnold on 01.02.23.
//

import SwiftUI

struct VerificationProgressView: View {
    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "finished == NO and pipeline == %@", Int(primaryVerificationPipeline.id) as NSNumber)
    )
    private var unverifiedStates: FetchedResults<VerificationState>
    
    var body: some View {
        ProgressView {
            Text("Verifying \(unverifiedStates.count) cellular \(unverifiedStates.count == 1 ? "measurement" : "measurements")")
        }
    }
}

struct VerificationProgressView_Previews: PreviewProvider {
    static var previews: some View {
        VerificationProgressView()
    }
}
