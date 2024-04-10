//
//  CellClusterAnnotationView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.01.23.
//

import Foundation
import MapKit

// https://developer.apple.com/documentation/mapkit/mkannotationview/decluttering_a_map_with_mapkit_annotation_clustering
class CellClusterAnnotationView: MKAnnotationView {
    
    static let ReuseID = "cellClusterAnnotation"
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        prepareForReuse()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(code:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        collisionMode = .circle
        displayPriority = .defaultHigh
    }
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
        
        if let cluster = annotation as? MKClusterAnnotation {
            let totalCells = cluster.memberAnnotations.count
            
            image = drawCellCount(count: totalCells)
        }
    }
    
    private func drawCellCount(count: Int) -> UIImage {
        // Size of the whole drawing area including the shadow
        let drawSize = 50.0
        // Size of the white circle
        let circleSize = 35.0
        // Offset to position everything in the center of the drawing area
        let offset = (drawSize - circleSize) / 2.0
        
        // Decrease the text size if the number gets larger
        let textSize: CGFloat
        if count < 1_000_000 {
            textSize = 14
        } else if count < 1_000 {
            textSize = 16
        } else {
            textSize = 18
        }
        
        // TODO: Consider using not the color white when in dark mode
        // let startTime = Date()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: drawSize, height: drawSize))
        let image = renderer.image { context in
            
            // Draw a shadow behind the circle
            // https://www.hackingwithswift.com/example-code/uikit/how-to-render-shadows-using-nsshadow-and-setshadow
            context.cgContext.setShadow(offset: .zero, blur: 10, color: UIColor.black.withAlphaComponent(0.5).cgColor)
            // Color the circle white
            UIColor.white.setFill()
            // Draw the circle with the specified size in the middle
            UIBezierPath(ovalIn: CGRect(x: offset, y: offset, width: circleSize, height: circleSize)).fill()
            // Reset the shadow
            context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            
            // Attributes for rendering text
            let attributes = [
                NSAttributedString.Key.foregroundColor: UIColor.black,
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: textSize)
            ]
            // The text content
            let text = "\(count)"
            // Calculate the size of the text box
            let size = text.size(withAttributes: attributes)
            // Position the text in the middle of the circle
            let rect = CGRect(
                x: offset + (circleSize / 2 - size.width / 2),
                y: offset + (circleSize / 2 - size.height / 2),
                width: size.width,
                height: size.height
            )
            // Draw the text in the rectangle
            text.draw(in: rect, withAttributes: attributes)
        }
        // print("Draw time: \(startTime.distance(to: Date()))")
        return image
    }
    
}
