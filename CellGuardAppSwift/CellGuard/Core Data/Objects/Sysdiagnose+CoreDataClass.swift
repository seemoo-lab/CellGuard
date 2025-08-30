//
//  Sysdiagnose+CoreDataClass.swift
//
//
//  Created by mp on 30.08.25.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData

@objc(Sysdiagnose)
public class Sysdiagnose: NSManagedObject {

    var cellCount: Int {
        return self.value(forKeyPath: "cells.@count") as? Int ?? 0
    }

    var connectivityEventCount: Int {
        return self.value(forKeyPath: "connectivityEvents.@count") as? Int ?? 0
    }

    var packetCount: Int {
        let packetAriCount = self.value(forKeyPath: "packetsARI.@count") as? Int ?? 0
        let packetQMICount = self.value(forKeyPath: "packetsQMI.@count") as? Int ?? 0
        return packetAriCount + packetQMICount
    }
}
