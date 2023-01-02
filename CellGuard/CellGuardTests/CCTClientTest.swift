//
//  CCTClientTest.swift
//  CellGuardTests
//
//  Created by Lukas Arnold on 01.01.23.
//

import XCTest
import Network
@testable import CellGuard

final class CCTClientTests: XCTestCase {
    
    private var listener: NWListener?
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // Load the CCTResponse.txt file (https://stackoverflow.com/a/23241781)
        let bundle = Bundle(for: type(of: self))
        let url = bundle.url(forResource: "CCTResponse", withExtension: "txt")!
        let cctData = try Data(contentsOf: url)
        // print(String(data: cctData, encoding: .utf8)!)
        
        // Create a new listener for this test
        listener = try NWListener(using: NWParameters.tcp, on: NWEndpoint.Port(integerLiteral: UInt16(33066)))
        listener?.stateUpdateHandler = {state in
            print("Test Listener State: \(state)")
        }
        // listener?.newConnectionLimit = 1
        listener?.newConnectionHandler = { connection in
            print("Test New Connection: \(connection)")

            connection.stateUpdateHandler = { state in
                print("Test Connection State: \(state)")
            }
            
            connection.start(queue: .main)
            
            connection.send(content: cctData, isComplete:true, completion: .contentProcessed({ (error: NWError?) -> Void in
                print("Test Connection Send Error: \(String(describing: error))")
                connection.cancel()
            }))
        }
        
        listener?.start(queue: .main)
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        if let listener = listener {
            listener.cancel()
        }
    }
    
    func testCollectCells() async throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
        let client = CCTClient(queue: DispatchQueue.main)
        
        do {
            let cells = try await withCheckedThrowingContinuation { continuation in
                client.collectCells() { result in
                    continuation.resume(with: result)
                }
            }
            print(cells)
            
            XCTAssertEqual(cells.count, 181)

        } catch {
            print(String(describing: error))
            throw error
        }
        
        
    }
    
}

