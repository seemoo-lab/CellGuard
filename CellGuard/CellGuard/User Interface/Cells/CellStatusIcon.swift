//
//  CellStatusIcon.swift
//  CellGuard
//
//  Created by Lukas Arnold on 20.01.23.
//

import SwiftUI

struct CellStatusIcon: View {
    
    let status: CellStatus?
    let score: Int16
    
    init(status: String?, score: Int16) {
        self.status = CellStatus(rawValue: status ?? "")
        self.score = score
    }
    
    var body: some View {
        if status == .verified {
            if score < CellVerifier.pointsUntrustedThreshold {
                Image(systemName: "exclamationmark.shield")
                    .font(.title2)
                    .foregroundColor(.red)
            } else if score < CellVerifier.pointsSuspiciousThreshold {
                Image(systemName: "shield")
                    .font(.title2)
                    .foregroundColor(.yellow)
            } else {
                Image(systemName: "lock.shield")
                    .font(.title2)
                    .foregroundColor(.green)
            }
        } else if status == .processedBandwidth && score == CellVerifier.pointsFastVerification {
            // We still monitoring the cell, but so far everything looks okay
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundColor(.green)
        } else if status == nil {
            Image(systemName: "questionmark.circle")
                .font(.title2)
                .foregroundColor(.gray)
        } else {
            ProgressView()
        }
    }
}

struct CellStatusIcon_Previews: PreviewProvider {
    static var previews: some View {
        CellStatusIcon(status: CellStatus.verified.rawValue, score: Int16(CellVerifier.pointsSuspiciousThreshold))
            .previewDisplayName("Verified")
        
        CellStatusIcon(status: CellStatus.verified.rawValue, score: Int16(CellVerifier.pointsUntrustedThreshold))
            .previewDisplayName("Suspicious")
        
        CellStatusIcon(status: CellStatus.verified.rawValue, score: 0)
            .previewDisplayName("Failed")
        
        CellStatusIcon(status: CellStatus.imported.rawValue, score: 0)
            .previewDisplayName("Imported")
        
        CellStatusIcon(status: nil, score: 0)
            .previewDisplayName("Nil")
    }
}
