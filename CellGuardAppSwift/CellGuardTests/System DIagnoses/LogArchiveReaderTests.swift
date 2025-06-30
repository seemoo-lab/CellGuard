//
//  CellGuardTests.swift
//  CellGuardTests
//
//  Created by mp on 22.06.25.
//

import XCTest
@testable import CellGuard_Jailbreak

final class LogArchiveReaderTests: XCTestCase {

    func testBeforeIOS26LogFormat() throws {
        let message = "Sent notification to 8 (of 45) clients: cellMonitorUpdate:<CTXPCServiceSubscriptionContext 0xb0a8938e0 slotID=CTSubscriptionSlotTwo, uuid=00000000-0000-0000-0000-000000000002, labelID=\"4711819D1-F11B-411F-11B0-4118E5111B3B\", label=\"Secondary\", phoneNumber=\"012345678901\", userDataPreferred=1, userDefaultVoice=1, isSimPresent=YES, isSimGood=YES> info:<CTCellInfo 0xb0ae3c1c0, info=(\n        {\n        kCTCellMonitorBandInfo = 1;\n        kCTCellMonitorBandwidth = 2;\n        kCTCellMonitorCSGIndication = 0;\n        kCTCellMonitorCellId = 1234567;\n        kCTCellMonitorCellRadioAccessTechnology = kCTCellMonitorRadioAccessTechnologyLTE;\n        kCTCellMonitorCellType = kCTCellMonitorCellTypeServing;\n        kCTCellMonitorCsgId = 1234567890;\n        kCTCellMonitorDeploymentType = 3;\n        kCTCellMonitorMCC = 123;\n        kCTCellMonitorMNC = 1;\n        kCTCellMonitorPID = 12;\n        kCTCellMonitorPMax = 12;\n        kCTCellMonitorRSRP = 0;\n        kCTCellMonitorRSRQ = 0;\n        kCTCellMonitorSectorLat = 0;\n        kCTCellMonitorSectorLong = 0;\n        kCTCellMonitorTAC = 12345;\n        kCTCellMonitorThroughput = 0;\n        kCTCellMonitorUARFCN = 1234;\n    }\n)"
        let cctProperties = try? LogArchiveReader().readCSVCellMeasurement(timestamp: Date(), message: message)
        XCTAssertNotNil(cctProperties)
    }

    func testAfterIOS26LogFormat() throws {
        let message = "Sent notification to 9 (of 52) clients: cellMonitorUpdate:<SubscriptionContext id=one> info:<CellInfo info=(\n        {\n        band = 1;\n        bandwidth = 2;\n        cellID = 1234567;\n        csgID = 1234567890;\n        csgIndication = 0;\n        deploymentType = 1;\n        mcc = 123;\n        mnc = 1;\n        pMax = 1;\n        pid = 123;\n        rat = LTE;\n        rsrp = 0;\n        rsrq = 0;\n        sectorLat = 0;\n        sectorLon = 0;\n        tac = 12345;\n        throughput = 0;\n        type = serving;\n        uarfcn = 1234;\n    },\n        {\n        bandwidth = 2;\n        neighborType = 3;\n        pci = 123;\n        rat = LTE;\n        rsrp = 1234;\n        rsrq = 1234;\n        throughput = 0;\n        type = neighbor;\n        uarfcn = 1234;\n    },\n)>"
        let cctProperties = try? LogArchiveReader().readCSVCellMeasurement(timestamp: Date(), message: message)
        XCTAssertNotNil(cctProperties)
    }

}
