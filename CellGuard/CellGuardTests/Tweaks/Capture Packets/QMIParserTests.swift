//
//  QMIParserTests.swift
//  CellGuardTests
//
//  Created by Lukas Arnold on 07.06.23.
//

import Foundation
import XCTest
@testable import CellGuard_Jailbreak

final class QMIParserTests: XCTestCase {
    
    func testCTLPacket() throws {
        // 269th packet from a private trace
        let data = Data(base64Encoded: "ARcAgAAAASIiAAwAAgQAAAAAAAECADAM")!
        let packet = try ParsedQMIPacket(nsData: data)
        
        XCTAssertEqual(packet.qmuxHeader.length, 23)
        XCTAssertEqual(packet.qmuxHeader.flag, 0x80)
        XCTAssertEqual(packet.qmuxHeader.serviceId, 0x00)
        XCTAssertEqual(packet.qmuxHeader.clientId, 0x00)
        
        XCTAssertEqual(packet.transactionHeader.compound, false)
        XCTAssertEqual(packet.transactionHeader.response, true)
        XCTAssertEqual(packet.transactionHeader.indication, false)
        XCTAssertEqual(packet.transactionHeader.transactionId, 0x22)
        
        XCTAssertEqual(packet.messageHeader.messageId, 0x0022)
        XCTAssertEqual(packet.messageHeader.messageLength, 12)
        
        XCTAssertEqual(packet.tlvs.count, 2)
        
        XCTAssertEqual(packet.tlvs[0].type, 0x02)
        XCTAssertEqual(packet.tlvs[0].length, 4)
        XCTAssertEqual(packet.tlvs[0].data, Data(count: 4))
        
        XCTAssertEqual(packet.tlvs[1].type, 0x01)
        XCTAssertEqual(packet.tlvs[1].length, 2)
        XCTAssertEqual(packet.tlvs[1].data, Data([0x30, 0x0C]))
    }
    
    func testCTLPacketWithEmptyTLV() throws {
        // Some packet collected during testing
        let data = Data(base64Encoded: "ARYAAAAAAJkpAAsAAQUAAQAAAAQRAAA=")!
        let packet = try ParsedQMIPacket(nsData: data)
        
        XCTAssertEqual(packet.qmuxHeader.length, 22)
        XCTAssertEqual(packet.qmuxHeader.flag, 0x00)
        XCTAssertEqual(packet.qmuxHeader.serviceId, 0x00)
        XCTAssertEqual(packet.qmuxHeader.clientId, 0x00)
        
        XCTAssertEqual(packet.transactionHeader.compound, false)
        XCTAssertEqual(packet.transactionHeader.response, false)
        XCTAssertEqual(packet.transactionHeader.indication, false)
        XCTAssertEqual(packet.transactionHeader.transactionId, 0x99)
        
        XCTAssertEqual(packet.messageHeader.messageId, 0x0029)
        XCTAssertEqual(packet.messageHeader.messageLength, 11)
        
        XCTAssertEqual(packet.tlvs.count, 2)
        
        XCTAssertEqual(packet.tlvs[0].type, 0x01)
        XCTAssertEqual(packet.tlvs[0].length, 5)
        XCTAssertEqual(packet.tlvs[0].data, Data([0x01, 0x00, 0x00, 0x00, 0x04]))
        
        XCTAssertEqual(packet.tlvs[1].type, 0x11)
        XCTAssertEqual(packet.tlvs[1].length, 0)
        XCTAssertEqual(packet.tlvs[1].data, Data(count: 0))
    }
    
    func testNASPacket() throws {
        // 1702th packet from a private trace
        let data = Data(base64Encoded: "AbYAgAMBBBYATgCqABACAAAAEQIAAAASAwAAAAATAwAAAAAUAwACAgAZHQABAwEDAQABAAD//wEDF+8AAAAAATI2MjAy/wF0tR4CAP//IQEAAScBAAAoBAABAAAAKgEAASsEAAEAAAAwBAAAAAAAMgQAAAAAADUCAP//OQQAAQAAADoEAAEAAAA/BAAAAAAARQQAAwAAAEcEAAQAAABMAwAAAABQAQABUQEAAFcBAAFdBAAAAAAA")!
        let packet = try ParsedQMIPacket(nsData: data)
        
        XCTAssertEqual(packet.qmuxHeader.length, 182)
        XCTAssertEqual(packet.qmuxHeader.flag, 0x80)
        XCTAssertEqual(packet.qmuxHeader.serviceId, 0x03)
        XCTAssertEqual(packet.qmuxHeader.clientId, 0x01)
        
        XCTAssertEqual(packet.transactionHeader.compound, false)
        XCTAssertEqual(packet.transactionHeader.response, false)
        XCTAssertEqual(packet.transactionHeader.indication, true)
        XCTAssertEqual(packet.transactionHeader.transactionId, 0x0016)
        
        XCTAssertEqual(packet.messageHeader.messageId, 0x004E)
        XCTAssertEqual(packet.messageHeader.messageLength, 170)
        
        XCTAssertEqual(packet.tlvs.count, 25)
        
        XCTAssertEqual(packet.tlvs[0].type, 0x10)
        XCTAssertEqual(packet.tlvs[0].length, 2)
        XCTAssertEqual(packet.tlvs[0].data, Data(count: 2))
        
        XCTAssertEqual(packet.tlvs[1].type, 0x11)
        XCTAssertEqual(packet.tlvs[1].length, 2)
        XCTAssertEqual(packet.tlvs[1].data, Data(count: 2))
        
        XCTAssertEqual(packet.tlvs[2].type, 0x12)
        XCTAssertEqual(packet.tlvs[2].length, 3)
        XCTAssertEqual(packet.tlvs[2].data, Data(count: 3))
        
        XCTAssertEqual(packet.tlvs[3].type, 0x13)
        XCTAssertEqual(packet.tlvs[3].length, 3)
        XCTAssertEqual(packet.tlvs[3].data, Data(count: 3))
        
        XCTAssertEqual(packet.tlvs[4].type, 0x14)
        XCTAssertEqual(packet.tlvs[4].length, 3)
        XCTAssertEqual(packet.tlvs[4].data, Data([0x02, 0x02, 0x00]))
        
        XCTAssertEqual(packet.tlvs[7].type, 0x21)
        XCTAssertEqual(packet.tlvs[7].length, 1)
        XCTAssertEqual(packet.tlvs[7].data, Data([0x01]))
    }
    
    func testInvalidPacket() throws {
        let data = Data(base64Encoded: "WwogICAgMS43NSwKICAgIDEuMjk4Nzk0OTQwNjk1Mzk4NSwKICAgIDEuMjk4Nzk0OTQwNjk1Mzk4NSwKICAgIDEuMDYxMjc4MTI0NDU5MTMzLAogICAgMC41NDM1NjQ0NDMxOTk1OTY0LAogICAgMS41NDg3OTQ5NDA2OTUzOTg1Cl0=")!
        XCTAssertThrowsError(try ParsedQMIPacket(nsData: data))
    }
    
}

