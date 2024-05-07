//
//  CellTweak+CoreDataClass.swift
//  CellGuard
//
//  Created by Lukas Arnold on 11.04.24.
//
//

import Foundation
import CoreData

@objc(CellTweak)
public class CellTweak: NSManagedObject, Cell {
    
    // TODO: Is this performant or should we add an additional relation to CellTweak?
    var primaryVerification: VerificationState? {
        return verifications?
            .compactMap({ $0 as? VerificationState })
            .first(where: { $0.pipeline == primaryVerificationPipeline.id })
    }
    
    var score: Int16 {
        return primaryVerification?.score ?? 0
    }
    
    var verificationFinished: Bool {
        return primaryVerification?.finished ?? false
    }

}
