//
//  CellStatusIcon.swift
//  CellGuard
//
//  Created by Lukas Arnold on 20.01.23.
//

import SwiftUI

struct CellStatusIcon: View {
    
    // It's important to mark this as an observable object, otherwise this status icon is not updated upon status updates
    // See: https://stackoverflow.com/a/64527233
    @ObservedObject var state: VerificationState
    
    var body: some View {
        if state.finished {
            if state.score < primaryVerificationPipeline.pointsUntrusted {
                Image(systemName: "exclamationmark.shield")
                    .font(.title2)
                    .foregroundColor(.red)
            } else if state.score < primaryVerificationPipeline.pointsSuspicious {
                Image(systemName: "shield")
                    .font(.title2)
                    .foregroundColor(.yellow)
            } else {
                Image(systemName: "lock.shield")
                    .font(.title2)
                    .foregroundColor(.green)
            }
        } else if state.stage >= primaryVerificationPipeline.stageNumberWaitingForPackets {
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundColor(.green)
        } else {
            ProgressView()
        }
    }
}

struct CellStatusIcon_Previews: PreviewProvider {
    static var previews: some View {
        // TODO: Rewrite
        
        /* CellStatusIcon(status: CellStatus.verified.rawValue, score: Int16(primaryVerificationPipeline.pointsSuspicious))
            .previewDisplayName("Verified")
        
        CellStatusIcon(status: CellStatus.verified.rawValue, score: Int16(primaryVerificationPipeline.pointsUntrusted))
            .previewDisplayName("Suspicious")
        
        CellStatusIcon(status: CellStatus.verified.rawValue, score: 0)
            .previewDisplayName("Failed")
        
        CellStatusIcon(status: CellStatus.imported.rawValue, score: 0)
            .previewDisplayName("Imported")
         
         // Imported Verifying
         
         */
        
        // TODO: CHANGE
        CellStatusIcon(state: VerificationState())
    }
}
