//
//  ScanProgressSheet.swift
//  CellGuard
//
//  Created by Lukas Arnold on 01.02.23.
//

import SwiftUI

struct VerificationProgressSheet: View {
    let close: () -> Void
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TweakCell.collected, ascending: false)],
        predicate: NSPredicate(format: "status == %@", CellStatus.imported.rawValue)
    )
    private var unverifedCells: FetchedResults<TweakCell>
    
    var body: some View {
        NavigationView {
            ProgressView {
                Text("Verifing \(unverifedCells.count) \(unverifedCells.count == 1 ? "cell" : "cells")")
            }
            .navigationTitle(Text("Progress"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem() {
                    Button {
                        close()
                    } label: {
                        Text("Done")
                            .bold()
                    }
                }
            }
        }
    }
}

struct ScanProgressSheet_Previews: PreviewProvider {
    static var previews: some View {
        VerificationProgressSheet { }
    }
}
