//
//  DatabaseAnnotation.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.01.23.
//

import CoreData
import MapKit

protocol DatabaseAnnotation: MKAnnotation {
    
    var coreDataID: NSManagedObjectID { get }
    
}
