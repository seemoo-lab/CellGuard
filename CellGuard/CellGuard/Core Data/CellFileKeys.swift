//
//  CellFileKeys.swift
//  CellGuard
//
//  Created by Lukas Arnold on 24.01.23.
//

import Foundation

struct CellFileKeys {
    static let connectedCells = "cells"
    static let alsCells = "alsCells"
    static let locations = "locations"
    static let packets = "packets"
    static let device = "device"
    static let date = "date"
}

struct ALSCellDictKeys {
    static let technology = "technology"
    static let country = "country"
    static let network = "network"
    static let area = "area"
    static let cell = "cell"
    static let frequency = "frequency"
    static let imported = "imported"
    static let location = "location"
}

struct ALSLocationDictKeys {
    static let horizontalAccuracy = "horizontalAccuracy"
    static let latitude = "latitude"
    static let longitude = "longitude"
    static let imported = "imported"
    static let reach = "reach"
    static let score = "score"
}

struct PacketDictKeys {
    static let direction = "direction"
    static let proto = "proto"
    static let collected = "collected"
    static let data = "data"
}
