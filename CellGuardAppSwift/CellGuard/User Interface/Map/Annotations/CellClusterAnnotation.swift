//
//  CellClusterAnnotation.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.01.23.
//

import Foundation
import MapKit

class CellClusterAnnotation: MKClusterAnnotation {

    let glyphText: String

    override init(memberAnnotations: [MKAnnotation]) {
        let count = memberAnnotations.count
        glyphText = count <= 99 ? "\(count)" : "99+"

        super.init(memberAnnotations: memberAnnotations)
        title = "\(memberAnnotations.count) Cells"
        subtitle = nil
    }

}
