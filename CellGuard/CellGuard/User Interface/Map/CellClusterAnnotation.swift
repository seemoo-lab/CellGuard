//
//  CellClusterAnnotation.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.01.23.
//

import Foundation
import MapKit

class CellClusterAnnotation: MKClusterAnnotation {
    
    override init(memberAnnotations: [MKAnnotation]) {
        super.init(memberAnnotations: memberAnnotations)
        title = "\(memberAnnotations.count) cells"
    }
    
}
