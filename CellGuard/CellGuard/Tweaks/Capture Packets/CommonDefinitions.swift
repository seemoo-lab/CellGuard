//
//  CommonDefinitions.swift
//  CellGuard
//
//  Created by Lukas Arnold on 08.06.23.
//

import Foundation

protocol CommonDefinitionElement: Decodable {
    
    var identifier: UInt16 { get }
    
}

extension CommonDefinitionElement {
    
    static func dictionary(_ elements: [Self]) -> [UInt16: Self]  {
        var dict: [UInt16: Self] = [:]
        for element in elements {
            dict[element.identifier] = element
        }
        return dict
    }
    
}
