//
//  ALSClientTests.swift
//  CellGuardTests
//
//  Created by Lukas Arnold on 01.01.23.
//

import XCTest
@testable import CellGuard_Jailbreak

final class ALSClientTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testRequestLTECell() async throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
        
        let client = ALSClient()
        let cells = try await client.requestCells(origin: ALSQueryCell(technology: .LTE, country: 262, network: 2, area: 46452, cell: 15669002))
        print("Got \(cells.count) cells")
        print("First cell: \(cells[0])")
        XCTAssertGreaterThan(cells.count, 0)
    }
    
    
    func testRequestGSMCell() async throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
        
        let client = ALSClient()
        let cells = try await client.requestCells(origin: ALSQueryCell(technology: .GSM, country: 262, network: 2, area: 566, cell: 4461))
        print("Got \(cells.count) cells")
        print("First cell: \(cells[0])")
        XCTAssertGreaterThan(cells.count, 0)
    }
    
    func testRequestUMTSCell() async throws {
        let client = ALSClient()
        let cells = try await client.requestCells(origin: ALSQueryCell(technology: .UMTS, country: 232, network: 1, area: 4106, cell: 3403674))
        print("Got \(cells.count) cells")
        print("First cell: \(cells[0])")
        XCTAssertGreaterThan(cells.count, 0)
    }

}
