//
//  ScanProgressSheet.swift
//  CellGuard
//
//  Created by Lukas Arnold on 01.02.23.
//

import SwiftUI

struct VerificationProgressView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TweakCell.collected, ascending: false)],
        predicate: NSPredicate(format: "status != %@", CellStatus.verified.rawValue)
    )
    private var unverifiedCells: FetchedResults<TweakCell>
    
    var body: some View {
        ProgressView {
            Text("Verifying \(unverifiedCells.count) cellular \(unverifiedCells.count == 1 ? "measurement" : "measurements")")
        }
    }
}

struct VerificationProgressView_Previews: PreviewProvider {
    static var previews: some View {
        VerificationProgressView()
    }
}
