//
//  ALSCellAnnotationView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.01.23.
//

import Foundation
import MapKit

class CellAnnotationView: MKMarkerAnnotationView {
    
    static let ReuseID = "cellAnnotation"
    
    init(annotation: MKAnnotation?, reuseIdentifier: String?, calloutAccessory: Bool) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = "cell"
        
        canShowCallout = true
        if calloutAccessory {
            rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(code:) has not been implemented")
    }
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
        displayPriority = .defaultLow
        markerTintColor = colorFromTechnology()
        glyphImage = UIImage(systemName: "antenna.radiowaves.left.and.right")
    }
    
    private func colorFromTechnology() -> UIColor {
        guard let annotation = annotation as? CellAnnotation else {
            return .systemGray
        }
        
        return CellTechnologyFormatter.mapColor(technology: annotation.technology)
    }
}
