//
//  ALSCellAnnotationView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.01.23.
//

import Foundation
import MapKit

class TowerAnnotationView: MKMarkerAnnotationView {
    
    static let ReuseID = "towerAnnotation"
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        prepareForReuse()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // It's crucial that we set those properties here, otherwise the cells disappear after zooming in and out
        
        animatesWhenAdded = false
        canShowCallout = true
        displayPriority = .required
        glyphImage = UIImage(systemName: "antenna.radiowaves.left.and.right")
    }
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
    }
    
    func updateColor(technology: ALSTechnology) {
        markerTintColor = CellTechnologyFormatter.mapColor(technology)
    }
}
