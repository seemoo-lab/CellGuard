//
//  ALSCellAnnotation.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.01.23.
//

import Foundation
import MapKit
import CoreData

class CellAnnotation: NSObject, MKAnnotation, DatabaseAnnotation {
    
    let coreDataID: NSManagedObjectID
    let technology: ALSTechnology
    
    @objc dynamic let coordinate: CLLocationCoordinate2D
    @objc dynamic let title: String?
    @objc dynamic let subtitle: String?
    
    init(cell: ALSCell) {
        coreDataID = cell.objectID
        technology = ALSTechnology(rawValue: cell.technology ?? "") ?? .LTE
        coordinate = CLLocationCoordinate2D(
            latitude: cell.location?.latitude ?? 0,
            longitude: cell.location?.longitude ?? 0
        )
        title = "Network \(cell.network)"
        subtitle = "Area: \(cell.area) - Cell: \(cell.cell)"
    }
    
}
