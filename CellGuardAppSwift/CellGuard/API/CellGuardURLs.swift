//
//  CellGuardURLs.swift
//  CellGuard
//
//  Created by Lukas Arnold on 18.04.24.
//

import Foundation

struct CellGuardURLs {

    #if LOCAL_BACKEND
    static let baseUrl = URL(string: "http://MacBook-Pro-von-Lukas.local")!
    #else
    static let baseUrl = URL(string: "https://cellguard.seemoo.de")!
    #endif

    static let docs = URL(string: "docs/", relativeTo: baseUrl)!
    static let privacyPolicy = URL(string: "privacy-policy", relativeTo: docs)!
    static let reportIssues = URL(string: "report-issues", relativeTo: docs)!
    static let installGuide = URL(string: "docs/install/#jailbroken-ios", relativeTo: baseUrl)!
    static let changelog = URL(string: "docs/changelog", relativeTo: baseUrl)!

    static let updateCheck = URL(string: "api/update-check", relativeTo: baseUrl)!
    static let api = URL(string: "api/submit/", relativeTo: baseUrl)!
    static let apiCells = URL(string: "cells", relativeTo: api)!
    static let apiWeekly = URL(string: "weekly", relativeTo: api)!

    static let github = URL(string: "https://github.com/seemoo-lab/CellGuard/")!
}
