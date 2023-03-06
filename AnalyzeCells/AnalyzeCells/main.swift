//
//  main.swift
//  AnalyzeCells
//
//  Created by Lukas Arnold on 09.02.23.
//

import Foundation

print("Hello, World!")

print(Date.distantPast.timeIntervalSince1970)

var dict: [String: Any] = [:]
dict["cool"] = Date.distantPast.timeIntervalSince1970

print(String(data: try JSONSerialization.data(withJSONObject: dict), encoding: .utf8))
