//
//  ARIDefinitionTests.swift
//  CellGuardTests
//
//  Created by Lukas Arnold on 08.06.23.
//

import Foundation
import XCTest
@testable import CellGuard__Jailbreak_

final class ARIDefinitionsTests: XCTestCase {
    
    func testBSPGroup() {
        XCTAssertEqual(ARIDefinitions.shared.groups.count, 33)
        
        let group = ARIDefinitions.shared.groups[0x01]
        XCTAssertNotNil(group)
        
        XCTAssertEqual(group?.identifier, 0x01)
        XCTAssertEqual(group?.name, "01_bsp")
        XCTAssertEqual(group?.types.count, 52)
    }
    
}
