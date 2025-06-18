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

    init(cell: CellALS, title: String? = nil, subtitle: String? = nil) {
        coreDataID = cell.objectID
        technology = ALSTechnology(rawValue: cell.technology ?? "") ?? .LTE
        coordinate = CLLocationCoordinate2D(
            latitude: cell.location?.latitude ?? 0,
            longitude: cell.location?.longitude ?? 0
        )
        self.title = title
        self.subtitle = subtitle
    }

    convenience init(cell: CellALS) {
        // Get the first available combined name
        let netOperators = OperatorDefinitions.shared.translate(country: cell.country, network: cell.network)

        self.init(
            cell: cell,
            title: netOperators.firstCombinedName ?? "Network \(formatMNC(cell.network))",
            subtitle: "Area: \(cell.area) - Cell: \(cell.cell)"
        )
    }

}
