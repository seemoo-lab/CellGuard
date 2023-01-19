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
    
    private func createTweakCell(context: NSManagedObjectContext, area: Int32, cell cellId: Int64) {
        context.performAndWait {
            let cell = TweakCell(context: context)
            
            cell.technology = ALSTechnology.LTE.rawValue
            cell.country = 262
            cell.network = 2
            cell.area = area
            cell.cell = cellId
            
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
    
    private func assertALSCellCount(assert: @escaping ([ALSCell]) -> ()) {
        let alsFetchRequest = NSFetchRequest<ALSCell>()
        alsFetchRequest.entity = ALSCell.entity()
        do {
            let alsCells = try alsFetchRequest.execute()
            assert(alsCells)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testVerifyValid() async throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
        
        let context = PersistenceController.shared.newTaskContext()
        
        createTweakCell(context: context, area: 46452, cell: 15669002)
        
        try await verify(n: 1)
        
        context.performAndWait {
            assertALSCellCount(assert: { cells in
                XCTAssertGreaterThan(cells.count, 0)
                cells.forEach { cell in
                    XCTAssertNotNil(cell.location)
                }
            })
            
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
        
        createTweakCell(context: context, area: 46452, cell: 15669002 + 99)
        
        try await verify(n: 1)
        
        context.performAndWait {
            assertALSCellCount(assert: { cells in
                XCTAssertEqual(cells.count, 0)
            })
            
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
        let context = PersistenceController.shared.newTaskContext()
        
        createTweakCell(context: context, area: 46452, cell: 15669002)
        createTweakCell(context: context, area: 46452, cell: 15669002 + 99)
        createTweakCell(context: context, area: 45711, cell: 12941845)
        
        try await verify(n: 5)
        
        context.performAndWait {
            assertALSCellCount(assert: { cells in
                XCTAssertGreaterThan(cells.count, 0)
                cells.forEach { cell in
                    XCTAssertNotNil(cell.location)
                }
            })
            
            do {
                // Test failed tweak cell
                let failedFetchRequest = NSFetchRequest<TweakCell>()
                failedFetchRequest.entity = TweakCell.entity()
                failedFetchRequest.predicate = NSPredicate(format: "status = %@", CellStatus.failed.rawValue)

                let failedTweakCells = try failedFetchRequest.execute()
                XCTAssertEqual(failedTweakCells.count, 1)
                
                let failedTweakCell = failedTweakCells.first!
                XCTAssertNil(failedTweakCell.verification)
                XCTAssertEqual(failedTweakCell.status, CellStatus.failed.rawValue)
                
                // Test verified tweak cell
                let verifiedFetchRequest = NSFetchRequest<TweakCell>()
                verifiedFetchRequest.entity = TweakCell.entity()
                verifiedFetchRequest.predicate = NSPredicate(format: "status = %@", CellStatus.verified.rawValue)
                
                let verifiedTweakCells = try verifiedFetchRequest.execute()
                XCTAssertEqual(verifiedTweakCells.count, 2)
                
                verifiedTweakCells.forEach { verifiedTweakCell in
                    XCTAssertNotNil(verifiedTweakCell.verification)
                    XCTAssertEqual(verifiedTweakCell.status, CellStatus.verified.rawValue)

                }
            } catch {
                XCTFail(error.localizedDescription)
            }

        }
    }
    
    func testVerifyExisting() async throws {
        let context = PersistenceController.shared.newTaskContext()
        
        createTweakCell(context: context, area: 46452, cell: 15669002)
        
        try await verify(n: 1)
        
        var firstALSCount = 0
        context.performAndWait {
            assertALSCellCount(assert: { cells in
                XCTAssertGreaterThan(cells.count, 0)
                firstALSCount = cells.count
                cells.forEach { cell in
                    XCTAssertNotNil(cell.location)
                }
            })
            
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
        
        createTweakCell(context: context, area: 46452, cell: 15669002)
        
        try await verify(n: 1)
        
        context.performAndWait {
            assertALSCellCount(assert: { cells in
                XCTAssertEqual(cells.count, firstALSCount)
            })
            
            let tweakFetchRequest = NSFetchRequest<TweakCell>()
            tweakFetchRequest.entity = TweakCell.entity()
            do {
                let tweakCells = try tweakFetchRequest.execute()
                XCTAssertEqual(tweakCells.count, 2)
                
                tweakCells.forEach { tweakCell in
                    XCTAssertNotNil(tweakCell.verification)
                    XCTAssertEqual(tweakCell.status, CellStatus.verified.rawValue)
                }
            } catch {
                XCTFail(error.localizedDescription)
            }

        }

    }

}
