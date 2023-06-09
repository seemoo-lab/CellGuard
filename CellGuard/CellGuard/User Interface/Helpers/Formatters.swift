//
//  Formatters.swift
//  CellGuard
//
//  Created by Lukas Arnold on 18.01.23.
//

import Foundation

let plainNumberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.usesSignificantDigits = false
    return formatter
}()

let mediumDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

let mediumDateTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

let fullMediumDateTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter
}()
