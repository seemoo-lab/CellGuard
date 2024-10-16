//
//  ALSVerifierTests.swift
//  CellGuardTests
//
//  Created by Lukas Arnold on 18.01.23.
//

import XCTest
import CoreData
@testable import CellGuard_Jailbreak

final class ALSVerifierTests: XCTestCase {
    
    // TODO: Completely rewrite those tests for the new pipeline infrastructure

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        let context = PersistenceController.shared.newTaskContext()
        context.performAndWait {
            do {
                let tweakDeleteRequest = NSBatchDeleteRequest(fetchRequest: CellTweak.fetchRequest())
                try context.execute(tweakDeleteRequest)
                
                let alsDeleteRequest = NSBatchDeleteRequest(fetchRequest: CellALS.fetchRequest())
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
                let tweakDeleteRequest = NSBatchDeleteRequest(fetchRequest: CellTweak.fetchRequest())
                try context.execute(tweakDeleteRequest)
                
                let alsDeleteRequest = NSBatchDeleteRequest(fetchRequest: CellALS.fetchRequest())
                try context.execute(alsDeleteRequest)
            } catch {
                print(error)
            }
        }
    }
    
    private func createTweakCell(context: NSManagedObjectContext, area: Int32, cell cellId: Int64) {
        context.performAndWait {
            let cell = CellTweak(context: context)
            
            cell.technology = ALSTechnology.LTE.rawValue
            cell.country = 262
            cell.network = 2
            cell.area = area
            cell.cell = cellId
            
            // cell.status = CellStatus.imported.rawValue
            // cell.score = 0
            // cell.nextVerification = Date()
            cell.imported = Date()
            cell.collected = Date()
            
            do {
                try context.save()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
    }
    
    private func assertALSCellCount(assert: @escaping ([CellALS]) -> ()) {
        let alsFetchRequest = NSFetchRequest<CellALS>()
        alsFetchRequest.entity = CellALS.entity()
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
        
        _ = try await CGVerificationPipeline().pickCellAndVerify()
        
        context.performAndWait {
            assertALSCellCount(assert: { cells in
                XCTAssertGreaterThan(cells.count, 0)
                cells.forEach { cell in
                    XCTAssertNotNil(cell.location)
                }
            })
            
            let tweakFetchRequest = NSFetchRequest<CellTweak>()
            tweakFetchRequest.entity = CellTweak.entity()
            do {
                let tweakCells = try tweakFetchRequest.execute()
                XCTAssertEqual(tweakCells.count, 1)
                
                let tweakCell = tweakCells.first!
                XCTAssertNotNil(tweakCell.appleDatabase)
                // XCTAssertEqual(tweakCell.status, CellStatus.processedLocation.rawValue)
                XCTAssertEqual(tweakCell.score, 60)
            } catch {
                XCTFail(error.localizedDescription)
            }

        }
    }
    
    func testVerifyFail() async throws {
        let context = PersistenceController.shared.newTaskContext()
        
        createTweakCell(context: context, area: 46452, cell: 15669002 + 99)
        
        _ = try await CGVerificationPipeline().pickCellAndVerify()
        
        context.performAndWait {
            assertALSCellCount(assert: { cells in
                XCTAssertEqual(cells.count, 0)
            })
            
            let tweakFetchRequest = NSFetchRequest<CellTweak>()
            tweakFetchRequest.entity = CellTweak.entity()
            do {
                let tweakCells = try tweakFetchRequest.execute()
                XCTAssertEqual(tweakCells.count, 1)
                
                let tweakCell = tweakCells.first!
                XCTAssertNil(tweakCell.appleDatabase)
                // XCTAssertEqual(tweakCell.status, CellStatus.processedLocation.rawValue)
                XCTAssertEqual(tweakCell.score, 0)
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
        
        _ = try await CGVerificationPipeline().pickCellAndVerify()
        _ = try await CGVerificationPipeline().pickCellAndVerify()
        _ = try await CGVerificationPipeline().pickCellAndVerify()
        
        context.performAndWait {
            assertALSCellCount(assert: { cells in
                XCTAssertGreaterThan(cells.count, 0)
                cells.forEach { cell in
                    XCTAssertNotNil(cell.location)
                }
            })
            
            do {
                let allCells = NSFetchRequest<CellTweak>()
                allCells.entity = CellTweak.entity()
                for cell in try allCells.execute() {
                    print("\(cell.cell): score=\(cell.score)")
                }
                print(try allCells.execute())
                
                // Test failed tweak cell
                let failedFetchRequest = NSFetchRequest<CellTweak>()
                failedFetchRequest.entity = CellTweak.entity()
                // failedFetchRequest.predicate = NSPredicate(format: "status = %@ and score = 0", CellStatus.processedLocation.rawValue)

                let failedTweakCells = try failedFetchRequest.execute()
                XCTAssertEqual(failedTweakCells.count, 1)
                
                // TODO: Understand how this fails
                let failedTweakCell = failedTweakCells.first!
                XCTAssertNil(failedTweakCell.appleDatabase)
                // XCTAssertEqual(failedTweakCell.status, CellStatus.processedLocation.rawValue)
                XCTAssertEqual(failedTweakCell.score, 0)
                
                // Test verified tweak cell
                let verifiedFetchRequest = NSFetchRequest<CellTweak>()
                verifiedFetchRequest.entity = CellTweak.entity()
                // verifiedFetchRequest.predicate = NSPredicate(format: "status = %@ and score > 0", CellStatus.processedLocation.rawValue)
                
                let verifiedTweakCells = try verifiedFetchRequest.execute()
                XCTAssertEqual(verifiedTweakCells.count, 2)
                
                verifiedTweakCells.forEach { verifiedTweakCell in
                    XCTAssertNotNil(verifiedTweakCell.appleDatabase)
                    // XCTAssertEqual(verifiedTweakCell.status, CellStatus.processedLocation.rawValue)

                }
            } catch {
                XCTFail(error.localizedDescription)
            }

        }
    }
    
    func testVerifyExisting() async throws {
        let context = PersistenceController.shared.newTaskContext()
        
        createTweakCell(context: context, area: 46452, cell: 15669002)
        
        _ = try await CGVerificationPipeline().pickCellAndVerify()
        
        var firstALSCount = 0
        context.performAndWait {
            assertALSCellCount(assert: { cells in
                XCTAssertGreaterThan(cells.count, 0)
                firstALSCount = cells.count
                cells.forEach { cell in
                    XCTAssertNotNil(cell.location)
                }
            })
            
            let tweakFetchRequest = NSFetchRequest<CellTweak>()
            tweakFetchRequest.entity = CellTweak.entity()
            do {
                let tweakCells = try tweakFetchRequest.execute()
                XCTAssertEqual(tweakCells.count, 1)
                
                let tweakCell = tweakCells.first!
                XCTAssertNotNil(tweakCell.appleDatabase)
                // XCTAssertEqual(tweakCell.status, CellStatus.processedLocation.rawValue)
                XCTAssertEqual(tweakCell.score, 60)
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
        
        createTweakCell(context: context, area: 46452, cell: 15669002)
        
        _ = try await CGVerificationPipeline().pickCellAndVerify()
        
        context.performAndWait {
            assertALSCellCount(assert: { cells in
                XCTAssertEqual(cells.count, firstALSCount)
            })
            
            let tweakFetchRequest = NSFetchRequest<CellTweak>()
            tweakFetchRequest.entity = CellTweak.entity()
            do {
                let tweakCells = try tweakFetchRequest.execute()
                XCTAssertEqual(tweakCells.count, 2)
                
                tweakCells.forEach { tweakCell in
                    XCTAssertNotNil(tweakCell.appleDatabase)
                    // XCTAssertEqual(tweakCell.status, CellStatus.processedLocation.rawValue)
                    XCTAssertEqual(tweakCell.score, 40)
                }
            } catch {
                XCTFail(error.localizedDescription)
            }

        }

    }

}
