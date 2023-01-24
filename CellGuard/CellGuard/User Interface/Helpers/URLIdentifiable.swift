//
//  URLIdentifiable.swift
//  CellGuard
//
//  Created by Lukas Arnold on 24.01.23.
//

import Foundation

struct URLIdentfiable: Identifiable {
    let id: String
    let url: URL
    
    init(url: URL) {
        self.id = url.absoluteString
        self.url = url
    }
}
