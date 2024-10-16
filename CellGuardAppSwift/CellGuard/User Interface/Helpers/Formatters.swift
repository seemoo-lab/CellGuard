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

let percentNumberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .percent
    formatter.minimumIntegerDigits = 1
    formatter.maximumIntegerDigits = 1
    formatter.maximumFractionDigits = 2
    return formatter
}()

private let mncNumberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimumIntegerDigits = 2
    formatter.usesSignificantDigits = false
    return formatter
}()

func formatMNC(_ mcc: Int32) -> String {
    return mncNumberFormatter.string(from: mcc as NSNumber) ?? "??"
}

let mediumDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

let mediumTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .medium
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
