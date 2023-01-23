//
//  LocationAnnotationView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.01.23.
//

import Foundation
import MapKit

class LocationAnnotationView: MKAnnotationView {
    
    static let ReuseID = "locationAnnotation"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = "location"
        collisionMode = .circle
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(code:) has not been implemented")
    }
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
        displayPriority = .defaultLow
        image = drawLocationDot()
    }
    
    private func drawLocationDot() -> UIImage {
        // Size of the whole drawing area including the shadow
        let drawSize = 15.0
        // Size of the white circle
        let circleSize = 10.0
        // Offset to position everything in the center of the drawing area
        let offset = (drawSize - circleSize) / 2.0
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: drawSize, height: drawSize))
        return renderer.image { context in
            // Draw a shadow behind the circle
            // https://www.hackingwithswift.com/example-code/uikit/how-to-render-shadows-using-nsshadow-and-setshadow
            context.cgContext.setShadow(offset: .zero, blur: 3, color: UIColor.black.withAlphaComponent(0.5).cgColor)
            // Color the circle white
            UIColor.systemBlue.setFill()
            // Draw the circle with the specified size in the middle
            UIBezierPath(ovalIn: CGRect(x: offset, y: offset, width: circleSize, height: circleSize)).fill()
            // Reset the shadow
            context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
        }
    }
    
}
