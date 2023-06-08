//
//  CommonDefinitions.swift
//  CellGuard
//
//  Created by Lukas Arnold on 08.06.23.
//

import Foundation

struct CommonDefinitionElement: Decodable {
    
    let identifier: UInt16
    let name: String
    
    static func dictionary(_ elements: [CommonDefinitionElement]) -> [UInt16: CommonDefinitionElement] {
        var dict: [UInt16: CommonDefinitionElement] = [:]
        for element in elements {
            dict[element.identifier] = element
        }
        return dict
    }
    
}
