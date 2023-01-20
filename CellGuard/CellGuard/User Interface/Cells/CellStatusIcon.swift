//
//  CellStatusIcon.swift
//  CellGuard
//
//  Created by Lukas Arnold on 20.01.23.
//

import SwiftUI

struct CellStatusIcon: View {
    
    let status: CellStatus?
    
    init(text: String?) {
        self.init(status: CellStatus(rawValue: text ?? ""))
    }
    
    init(status: CellStatus?) {
        self.status = status
    }
    
    var body: some View {
        if status == .verified {
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundColor(.green)
        } else if status == .failed {
            Image(systemName: "exclamationmark.shield")
                .font(.title2)
                .foregroundColor(.red)
        } else if status == .imported {
            ProgressView()
        } else {
            Image(systemName: "questionmark.circle")
                .font(.title2)
                .foregroundColor(.gray)
        }
    }
}

struct CellStatusIcon_Previews: PreviewProvider {
    static var previews: some View {
        CellStatusIcon(status: CellStatus.verified)
            .previewDisplayName("Verified")
        
        CellStatusIcon(status: CellStatus.failed)
            .previewDisplayName("Failed")
        
        CellStatusIcon(status: CellStatus.imported)
            .previewDisplayName("Imported")
        
        CellStatusIcon(status: nil)
            .previewDisplayName("Nil")
    }
}
