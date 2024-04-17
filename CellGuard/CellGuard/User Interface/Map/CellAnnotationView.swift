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
    
    var calloutAccessory: Bool {
        get {
            rightCalloutAccessoryView != nil
        }
        set (newVal) {
            rightCalloutAccessoryView = newVal ? UIButton(type: .detailDisclosure) : nil
        }
    }
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        prepareForReuse()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(code:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // It's crucial that we set those properties here, otherwise the cells disappear after zooming in and out
        clusteringIdentifier = "cell"
        animatesWhenAdded = false
        canShowCallout = true
        displayPriority = .required
        glyphImage = UIImage(systemName: "antenna.radiowaves.left.and.right")
    }
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
    }
    
    func updateColor(technology: ALSTechnology) {
        markerTintColor = CellTechnologyFormatter.mapColor(technology: technology)
    }
}
