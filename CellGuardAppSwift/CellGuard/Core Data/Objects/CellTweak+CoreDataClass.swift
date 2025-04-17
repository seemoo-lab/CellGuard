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
public class CellTweak: NSManagedObject, Encodable, Cell {
    
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
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.area, forKey: .area)
        try container.encode(self.band, forKey: .band)
        try container.encode(self.bandwidth, forKey: .bandwidth)
        try container.encode(self.collected, forKey: .collected)
        try container.encode(self.country, forKey: .country)
        try container.encode(self.frequency, forKey: .frequency)
        try container.encode(self.network, forKey: .network)
        try container.encode(self.physicalCell, forKey: .physicalCell)
        try container.encode(self.preciseTechnology, forKey: .preciseTechnology)
        try container.encode(self.technology, forKey: .technology)
    }
    
    enum CodingKeys: String, CodingKey {
        case area
        case band
        case bandwidth
        case cell
        case collected
        case country
        case frequency
        case imported
        case network
        case physicalCell
        case preciseTechnology
        case technology
    }
    
    // If a deployment type > 0 is set, the cell supports 5G NSA
    public func supports5gNsa() -> Bool {
        return self.technology == "LTE" && self.deploymentType > 0
    }

}
