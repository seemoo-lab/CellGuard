//
//  CellClusterAnnotationView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.01.23.
//

import Foundation
import MapKit

// https://developer.apple.com/documentation/mapkit/mkannotationview/decluttering_a_map_with_mapkit_annotation_clustering
class CellClusterAnnotationView: MKMarkerAnnotationView {
    
    static let ReuseID = "cellClusterAnnotation"
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        prepareForReuse()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        displayPriority = .defaultHigh
        markerTintColor = .white
        titleVisibility = .adaptive
        animatesWhenAdded = false
    }
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
        
        if let cluster = annotation as? CellClusterAnnotation {
            glyphText = cluster.glyphText
        }
    }
    
}
