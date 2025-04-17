//
//  ARIParserTests.swift
//  CellGuardTests
//
//  Created by Lukas Arnold on 07.06.23.
//

import Foundation
import XCTest
@testable import CellGuard_Jailbreak

final class ARIParserTests: XCTestCase {

    // Packets extracted from https://github.com/seemoo-lab/aristoteles/blob/master/examples/captures/cellinfo_nosim.pcapng

    func testFirstPacket() throws {
        // 1st packet from the trace
        let data = Data(base64Encoded: "3sB+q3igoABCwAAAAiAQAAAAAAAGIBAA8BMAAAggEAAAAAAACiCwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADCAQAAAAAAA=")!
        let packet = try ParsedARIPacket(data: data)

        XCTAssertEqual(packet.header.sequenceNumber, 592)
        XCTAssertEqual(packet.header.group, 15)
        XCTAssertEqual(packet.header.type, 0x301)
        XCTAssertEqual(packet.header.length, 80)
        XCTAssertEqual(packet.header.transaction, 0x00000000)
        XCTAssertEqual(packet.header.acknowledgement, false)

        XCTAssertEqual(packet.tlvs.count, 5)

        XCTAssertEqual(packet.tlvs[0].type, 1)
        XCTAssertEqual(packet.tlvs[0].version, 1)
        XCTAssertEqual(packet.tlvs[0].length, 4)
        XCTAssertEqual(packet.tlvs[0].data, Data(count: 4))

        XCTAssertEqual(packet.tlvs[1].type, 3)
        XCTAssertEqual(packet.tlvs[1].version, 1)
        XCTAssertEqual(packet.tlvs[1].length, 4)
        XCTAssertEqual(packet.tlvs[1].data, Data([0xF0, 0x13, 0x00, 0x00]))

        XCTAssertEqual(packet.tlvs[2].type, 4)
        XCTAssertEqual(packet.tlvs[2].version, 1)
        XCTAssertEqual(packet.tlvs[2].length, 4)
        XCTAssertEqual(packet.tlvs[2].data, Data(count: 4))

        XCTAssertEqual(packet.tlvs[3].type, 5)
        XCTAssertEqual(packet.tlvs[3].version, 1)
        XCTAssertEqual(packet.tlvs[3].length, 44)
        XCTAssertEqual(packet.tlvs[3].data, Data(count: 44))

        XCTAssertEqual(packet.tlvs[4].type, 6)
        XCTAssertEqual(packet.tlvs[4].version, 1)
        XCTAssertEqual(packet.tlvs[4].length, 4)
        XCTAssertEqual(packet.tlvs[4].data, Data(count: 4))

        XCTAssertEqual(try packet.write(), data)
    }

    func testSecondPacket() throws {
        // 19th packet from the trace
        let data = Data(base64Encoded: "3sB+qxjENAHCwgAAAiAQAAAAAAAEIAQA8QYgBAAyCCAQABQAAAAKIFAAAAAAAAAAAAAAAAAAAAAAADIAAAAMIJAB8TIAAAAAAAAAAAAAAAAAAAAAMgAAAAMAAAA34gAA0cIAAETB8////5j///8AAAAAAAAAAAAAAAAAAAAAAAAAAAYAAAAAAAAAWOQbhRiAHIUQOvCEAAAAAABgsFEAAAAAkXDfhQ==")!
        let packet = try ParsedARIPacket(data: data)

        XCTAssertEqual(packet.header.sequenceNumber, 610)
        XCTAssertEqual(packet.header.group, 3)
        XCTAssertEqual(packet.header.type, 0x30B)
        XCTAssertEqual(packet.header.length, 154)
        XCTAssertEqual(packet.header.transaction, 0x00000000)
        XCTAssertEqual(packet.header.acknowledgement, false)

        XCTAssertEqual(packet.tlvs.count, 6)

        XCTAssertEqual(packet.tlvs[0].type, 1)
        XCTAssertEqual(packet.tlvs[0].version, 1)
        XCTAssertEqual(packet.tlvs[0].length, 4)
        XCTAssertEqual(packet.tlvs[0].data, Data(count: 4))

        XCTAssertEqual(packet.tlvs[1].type, 2)
        XCTAssertEqual(packet.tlvs[1].version, 1)
        XCTAssertEqual(packet.tlvs[1].length, 1)
        XCTAssertEqual(packet.tlvs[1].data, Data([0xF1]))

        XCTAssertEqual(packet.tlvs[2].type, 3)
        XCTAssertEqual(packet.tlvs[2].version, 1)
        XCTAssertEqual(packet.tlvs[2].length, 1)
        XCTAssertEqual(packet.tlvs[2].data, Data([0x32]))

        XCTAssertEqual(packet.tlvs[3].type, 4)
        XCTAssertEqual(packet.tlvs[3].version, 1)
        XCTAssertEqual(packet.tlvs[3].length, 4)
        XCTAssertEqual(packet.tlvs[3].data, Data([0x14, 0x00, 0x00, 0x00]))

        XCTAssertEqual(packet.tlvs[4].type, 5)
        XCTAssertEqual(packet.tlvs[4].version, 1)
        XCTAssertEqual(packet.tlvs[4].length, 20)
        XCTAssertEqual(packet.tlvs[4].data, Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x32, 0x00, 0x00, 0x00]))

        XCTAssertEqual(packet.tlvs[5].type, 6)
        XCTAssertEqual(packet.tlvs[5].version, 1)
        XCTAssertEqual(packet.tlvs[5].length, 100)
        // We've omitted its data check

        XCTAssertEqual(try packet.write(), data)
    }

    func testFunc() throws {
        let data = Data(base64Encoded: "3sB+q4hgMBFNQghUBiAQAAIAAAAIIBAAAAAAAAogEAAIAAAADCAIAMgADiAEAP8QIAQAgRIgBAJiNTBiOWIyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAUIBAAAAAAABYgEAAAAAAAGCAIANEHGiBEH1NJUC8yLjAgMjAwIE9LDQpWaWE6IFNJUC8yLjAvVENQIFsyYTAxOjU5ODo0MDI6MzAwMjo6MTJdOjUwNjM7YnJhbmNoPXo5aEc0YktnM1pxa3Y3aWtpN253azVvY3hvOG5ydmtobGwxbXBjcW0NClRvOiA8c2lwOis0OTE1MTUyMjkxMDEyQGltcy50ZWxla29tLmRlPjt0YWc9SHlKSVBrRW5pZw0KRnJvbTogPHNpcDorNDkxNTE1MjI5MTAxMkBpbXMudGVsZWtvbS5kZT47dGFnPWg3ZzRFc2JnXzcyNzhmYWE3MDE5ZjA2MDVmZTdiMDNkYWFiNGQNCkNhbGwtSUQ6IFZvaGxwM2hXQ2NIdTMza2cxeDVhSnZiYg0KQ1NlcTogNjU3MDcgTk9USUZZDQpDb250ZW50LUxlbmd0aDogMA0KDQoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==")
        let packet = try ParsedARIPacket(data: data!)
        print(packet)

        XCTAssertEqual(try packet.write(), data)
    }

    func testInvalidPacket() throws {
        let data = Data(base64Encoded: "WwogICAgMS40MDU2MzkwNjIyMjk1NjY1LAogICAgMi4yNSwKICAgIDIuNSwKICAgIDIuNSwKICAgIDIuMjUKXQ==")!
        XCTAssertThrowsError(try ParsedARIPacket(data: data))
    }

}
