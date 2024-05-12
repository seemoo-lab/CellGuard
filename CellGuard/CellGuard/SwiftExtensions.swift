//
//  SwiftExtensions.swift
//  CellGuard
//
//  Created by Lukas Arnold on 28.07.23.
//

import Foundation

// https://stackoverflow.com/a/40868784
extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

#if swift(<5.1)
extension Strideable where Stride: SignedInteger {
    func clamped(to limits: CountableClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
#endif

// https://stackoverflow.com/a/30593673
extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
