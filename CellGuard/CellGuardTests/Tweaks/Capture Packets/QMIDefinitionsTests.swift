//
//  QMIDefinitionsTests.swift
//  CellGuardTests
//
//  Created by Lukas Arnold on 08.06.23.
//

import Foundation
import XCTest
@testable import CellGuard__Jailbreak_

final class QMIDefinitionsTests: XCTestCase {
    
    func testNASService() {
        XCTAssertEqual(QMIDefinitions.shared.services.count, 32)
        
        let service = QMIDefinitions.shared.services[0x03]
        XCTAssertNotNil(service)
        
        XCTAssertEqual(service?.identifier, 0x03)
        XCTAssertEqual(service?.shortName, "nas")
        XCTAssertEqual(service?.longName, "Network Access Service")
        XCTAssertEqual(service?.messages.count, 47)
        XCTAssertEqual(service?.indications.count, 27)
    }
    
}
