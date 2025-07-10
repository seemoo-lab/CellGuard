//
//  ConnectivityEventParser.swift
//  CellGuard
//
//  Created by mp on 08.07.25.
//

import Foundation
import BinarySwift

enum ConnectivityParserError: Error {
    case invalidDirection
    case invalidQmiMessage
    case missingQmiOperationMode
}

struct ParsedConnectivityEvent {
    var active: Bool
    var timestamp: Date

    var simSlot: UInt8?
    var basebandMode: UInt8?

    func applyTo(connectivityEvent: ConnectivityEvent) {
        connectivityEvent.active = self.active
        connectivityEvent.collected = self.timestamp

        connectivityEvent.simSlot = self.simSlot != nil ? Int16(self.simSlot!) : 0
        connectivityEvent.basebandMode = self.basebandMode != nil ? Int16(self.basebandMode!) : -1
    }
}

/* For us, a Connectvivity Event is an event that states if the baseband is connected to a cell or not. */
struct ConnectivityEventParser {
    static func isConnectivityEventPacket(qmi: PacketQMI?, ari: PacketARI?) -> Bool {
        if let qmi = qmi {
            guard let direction = qmi.direction,
                  CPTDirection(rawValue: direction) == .outgoing else {
                return false
            }

            switch (qmi.service, qmi.message) {
            case (Int16(PacketConstants.qmiConnectivityWDSService), Int32(PacketConstants.qmiConnectivityStartNetworkMessageId)),
                (Int16(PacketConstants.qmiConnectivityWDSService), Int32(PacketConstants.qmiConnectivityStopNetworkMessageId)),
                (Int16(PacketConstants.qmiConnectivityDMSService), Int32(PacketConstants.qmiConnectivitySetOperatingModeMessageId)):
                return true
            default:
                return false
            }
        } else if let ari = ari {
            // ToDo
        }
        return false
    }

    /*
     We use three different QMI packet types to determine connectivity events:
     1) "Start Network" packets: SIM-specific
     2) "Stop Network" packets: SIM-specific
     3) "Set Operating Mode" packets: Hardware-related. Just triggered with Airplane Mode.
     */
    func parseQmiPacket(_ data: Data, timestamp: Date, simSlot: UInt8) throws -> ParsedConnectivityEvent {
        let parsedPacket = try ParsedQMIPacket(nsData: data)

        if parsedPacket.transactionHeader.indication || parsedPacket.transactionHeader.response {
            throw ConnectivityParserError.invalidDirection
        }

        switch (parsedPacket.qmuxHeader.serviceId, parsedPacket.messageHeader.messageId) {
        case (PacketConstants.qmiConnectivityWDSService, PacketConstants.qmiConnectivityStartNetworkMessageId):
            return parseQMIStartNetworkEvent(parsedPacket, timestamp: timestamp, simSlot: simSlot)
        case (PacketConstants.qmiConnectivityWDSService, PacketConstants.qmiConnectivityStopNetworkMessageId):
            return parseQMIStopNetworkEvent(parsedPacket, timestamp: timestamp, simSlot: simSlot)
        case (PacketConstants.qmiConnectivityDMSService, PacketConstants.qmiConnectivitySetOperatingModeMessageId):
            return try parseQMISetOperatingModeEvent(parsedPacket, timestamp: timestamp, simSlot: simSlot)
        default:
            throw ConnectivityParserError.invalidQmiMessage
        }
    }

    private func parseQMIStartNetworkEvent(_ parsedPacket: ParsedQMIPacket, timestamp: Date, simSlot: UInt8) -> ParsedConnectivityEvent {
        return ParsedConnectivityEvent(active: true, timestamp: timestamp, simSlot: simSlot)
    }

    private func parseQMIStopNetworkEvent(_ parsedPacket: ParsedQMIPacket, timestamp: Date, simSlot: UInt8) -> ParsedConnectivityEvent {
        return ParsedConnectivityEvent(active: false, timestamp: timestamp, simSlot: simSlot)
    }

    /*
    * See libQMI
    * QmiDmsOperatingMode:
    * @QMI_DMS_OPERATING_MODE_ONLINE: Device can acquire a system and make calls.
    * @QMI_DMS_OPERATING_MODE_LOW_POWER: Device has temporarily disabled RF.
    * @QMI_DMS_OPERATING_MODE_PERSISTENT_LOW_POWER: Device has disabled RF and state persists even after a reset.
    * @QMI_DMS_OPERATING_MODE_FACTORY_TEST: Special mode for manufacturer tests.
    * @QMI_DMS_OPERATING_MODE_OFFLINE: Device has deactivated RF and is partially shutdown.
    * @QMI_DMS_OPERATING_MODE_RESET: Device is in the process of power cycling.
    * @QMI_DMS_OPERATING_MODE_SHUTTING_DOWN: Device is in the process of shutting down.
    * @QMI_DMS_OPERATING_MODE_MODE_ONLY_LOW_POWER: Mode-only Low Power.
    * @QMI_DMS_OPERATING_MODE_UNKNOWN: Unknown.
    */
    private func parseQMISetOperatingModeEvent(_ parsedPacket: ParsedQMIPacket, timestamp: Date, simSlot: UInt8) throws -> ParsedConnectivityEvent {
        guard let modeTlv = parsedPacket.findTlvValue(type: PacketConstants.qmiConnectivitySetOperationModeTlvType) else {
            throw ConnectivityParserError.missingQmiOperationMode
        }

        let data = BinaryData(data: modeTlv.data, bigEndian: false)
        let mode: UInt8 = try data.get(0)
        let active = mode == 0
        return ParsedConnectivityEvent(active: active, timestamp: timestamp, simSlot: simSlot, basebandMode: mode)
    }
}
