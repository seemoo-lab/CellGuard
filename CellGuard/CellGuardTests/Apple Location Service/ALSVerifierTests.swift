//
//  ALSVerifierTests.swift
//  CellGuardTests
//
//  Created by Lukas Arnold on 18.01.23.
//

import XCTest
import CoreData
@testable import CellGuard

final class ALSVerifierTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        let context = PersistenceController.shared.newTaskContext()
        context.performAndWait {
            do {
                let tweakDeleteRequest = NSBatchDeleteRequest(fetchRequest: NSFetchRequest(entityName: "TweakCell"))
                try context.execute(tweakDeleteRequest)
                
                let alsDeleteRequest = NSBatchDeleteRequest(fetchRequest: NSFetchRequest(entityName: "ALSCell"))
                try context.execute(alsDeleteRequest)
            } catch {
                print(error)
            }
        }
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        let context = PersistenceController.shared.newTaskContext()
        context.performAndWait {
            do {
                let tweakDeleteRequest = NSBatchDeleteRequest(fetchRequest: NSFetchRequest(entityName: "TweakCell"))
                try context.execute(tweakDeleteRequest)
                
                let alsDeleteRequest = NSBatchDeleteRequest(fetchRequest: NSFetchRequest(entityName: "ALSCell"))
                try context.execute(alsDeleteRequest)
            } catch {
                print(error)
            }
        }
    }
    
    private func createTweakCell(context: NSManagedObjectContext, cellIdAdd: Int64 = 0) {
        context.performAndWait {
            let cell = TweakCell(context: context)
            
            cell.technology = ALSTechnology.LTE.rawValue
            cell.country = 262
            cell.network = 2
            cell.area = 46452
            cell.cell = 15669002 + cellIdAdd
            
            cell.status = CellStatus.imported.rawValue
            cell.imported = Date()
            cell.collected = Date()
            
            do {
                try context.save()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
    }
    
    private func verify(n: Int) async throws {
        let _: Int = try await withCheckedThrowingContinuation { continuation in
            ALSVerifier().verify(n: n) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: 0)
                }
            }
        }
    }
    
    func testVerifyValid() async throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
        
        let context = PersistenceController.shared.newTaskContext()
        
        createTweakCell(context: context)
        
        try await verify(n: 1)
        
        context.performAndWait {
            let alsFetchRequest = NSFetchRequest<ALSCell>()
            alsFetchRequest.entity = ALSCell.entity()
            do {
                let alsCells = try alsFetchRequest.execute()
                XCTAssertGreaterThan(alsCells.count, 0)
            } catch {
                XCTFail(error.localizedDescription)
            }
            
            let tweakFetchRequest = NSFetchRequest<TweakCell>()
            tweakFetchRequest.entity = TweakCell.entity()
            do {
                let tweakCells = try tweakFetchRequest.execute()
                XCTAssertEqual(tweakCells.count, 1)
                
                let tweakCell = tweakCells.first!
                XCTAssertNotNil(tweakCell.verification)
                XCTAssertEqual(tweakCell.status, CellStatus.verified.rawValue)
            } catch {
                XCTFail(error.localizedDescription)
            }

        }
        

    }
    
    func testVerifyFail() async throws {
        let context = PersistenceController.shared.newTaskContext()
        
        createTweakCell(context: context, cellIdAdd: 99)
        
        try await verify(n: 1)
        
        context.performAndWait {
            let alsFetchRequest = NSFetchRequest<ALSCell>()
            alsFetchRequest.entity = ALSCell.entity()
            do {
                let alsCells = try alsFetchRequest.execute()
                XCTAssertEqual(alsCells.count, 0)
            } catch {
                XCTFail(error.localizedDescription)
            }
            
            let tweakFetchRequest = NSFetchRequest<TweakCell>()
            tweakFetchRequest.entity = TweakCell.entity()
            do {
                let tweakCells = try tweakFetchRequest.execute()
                XCTAssertEqual(tweakCells.count, 1)
                
                let tweakCell = tweakCells.first!
                XCTAssertNil(tweakCell.verification)
                XCTAssertEqual(tweakCell.status, CellStatus.failed.rawValue)
            } catch {
                XCTFail(error.localizedDescription)
            }

        }
    }
    
    func testVerifyMultiple() async throws {
        
    }

}
