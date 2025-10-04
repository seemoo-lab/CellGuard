//
//  ConnectivityEvent+CoreDataClass.swift
//  
//
//  Created by mp on 02.09.25.
//

import Foundation
import CoreData

@objc(ConnectivityEvent)
public class ConnectivityEvent: NSManagedObject {

    var simUnlocked: Bool? {
        get { rawSimUnlocked?.boolValue }
        set { rawSimUnlocked = newValue.map { NSNumber(value: $0) } }
    }

    var title: String {
        return switch (self.active, self.simUnlocked) {
        case (true, .none):
            "Connected"
        case (true, .some(false)):
            "SIM Inserted"
        case (true, .some(true)):
            "SIM Unlocked"
        case (false, .none):
            "Disconnected"
        case (false, .some):
            "SIM Removed"
        }
    }
}
