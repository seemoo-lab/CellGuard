//
//  FirstLastDates.swift
//  CellGuard
//
//  Created by Lukas Arnold on 10.04.24.
//

import Foundation

class FirstLastDates {

    var first: Date?
    var last: Date?

    init() {

    }

    func update(_ date: Date) {
        if let first = first {
            if date < first {
                self.first = date
            }
        } else {
            first = date
        }

        if let last = last {
            if date > last {
                self.last = date
            }
        } else {
            last = date
        }
    }

}
