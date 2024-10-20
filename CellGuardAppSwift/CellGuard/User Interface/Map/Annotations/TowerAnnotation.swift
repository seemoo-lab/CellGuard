//
//  TowerAnnotation.swift
//  CellGuard
//
//  Created by Lukas Arnold on 20.10.24.
//

import Foundation
import MapKit
import CoreData

class TowerAnnotation: NSObject, MKAnnotation {
    
    let technology: ALSTechnology
    
    @objc dynamic let coordinate: CLLocationCoordinate2D
    @objc dynamic let title: String?
    @objc dynamic let subtitle: String?
    
    init(technology: ALSTechnology, coordinate: CLLocationCoordinate2D, title: String? = nil, subtitle: String? = nil) {
        self.technology = technology
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
    }
    
}
