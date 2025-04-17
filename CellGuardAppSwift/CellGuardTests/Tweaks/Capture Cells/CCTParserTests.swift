//
//  CCTParserTests.swift
//  CellGuardTests
//
//  Created by Lukas Arnold on 06.01.23.
//

import XCTest
import Network
@testable import CellGuard_Jailbreak

final class CCTParserTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testParseFile() async throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.

        // Load the CCTResponse.txt file (https://stackoverflow.com/a/23241781)
        let bundle = Bundle(for: type(of: self))
        let url = bundle.url(forResource: "CCTResponse", withExtension: "txt")!
        let cctString = String(data: try Data(contentsOf: url), encoding: .utf8)!

        // Convert the string from JSON into objects
        let jsonFriendlyStr = "[\(cctString.split(whereSeparator: \.isNewline).joined(separator: ", "))]"
        guard let jsonData = try JSONSerialization.jsonObject(with: jsonFriendlyStr.data(using: .utf8)!) as? [CellSample] else {
            XCTFail("JSON Data does not match expected format")
            return
        }

        // Test whether the parser can successfully read all entities
        let parser = CCTParser()

        do {
            try jsonData.forEach { sample in
                print("Trying to parse: \(sample)")
                _ = try parser.parse(sample)
            }
            print("All items could be parsed successfully")
        } catch {
            print(String(describing: error))
            throw error
        }

    }

}
