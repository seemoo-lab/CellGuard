//
//  PortStatus.swift
//  CellGuard
//
//  Created by Lukas Arnold on 25.09.23.
//

import Atomics
import Foundation

struct PortStatus {

    static var importActive = ManagedAtomic<Bool>(false)
    static var exportActive = ManagedAtomic<Bool>(false)

}
