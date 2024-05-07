//
//  SNVerificationPipeline.swift
//  CellGuard
//
//  Created by Lukas Arnold on 06.05.24.
//

import OSLog

struct SNVerificationPipeline: VerificationPipeline {
    
    var logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: SNVerificationPipeline.self)
    )
    
    var id: Int16 = 2
    var name = "SnoopSnitch"
    
    var stages: [any VerificationStage] = [
        // TODO: @Linus Implement pipeline stages
    ]
    
    static var instance = SNVerificationPipeline()
    
}
