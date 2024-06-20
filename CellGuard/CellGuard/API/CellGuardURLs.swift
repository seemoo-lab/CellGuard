//
//  CellGuardURLs.swift
//  CellGuard
//
//  Created by Lukas Arnold on 18.04.24.
//

import Foundation

struct CellGuardURLs {
    
    static let baseUrl = URL(string: "https://cellguard.seemoo.de")!
    
    static let docs = URL(string: "docs/", relativeTo: baseUrl)!
    static let privacyPolicy = URL(string: "privacy-policy", relativeTo: docs)!
    
    static let api = URL(string: "api/", relativeTo: baseUrl)!
    static let apiCells = URL(string: "cells", relativeTo: api)!
    static let apiWeekly = URL(string: "weekly", relativeTo: api)!
    
}
