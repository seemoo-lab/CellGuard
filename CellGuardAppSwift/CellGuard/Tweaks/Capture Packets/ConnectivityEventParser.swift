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
    case invalidMessage
    case missingQmiOperationMode
    case invalidAriPacket
    case missingRequiredTlv
}

struct ParsedConnectivityEvent {
    var active: Bool
    var timestamp: Date

    var simSlot: UInt8?

    var basebandMode: UInt8?
    var registrationStatus: UInt8?
    var simUnlocked: Bool?

    func applyTo(connectivityEvent: ConnectivityEvent) {
        connectivityEvent.active = self.active
        connectivityEvent.collected = self.timestamp

        connectivityEvent.simSlot = self.simSlot != nil ? Int16(self.simSlot!) : 0
        connectivityEvent.basebandMode = self.basebandMode != nil ? Int16(self.basebandMode!) : -1
        connectivityEvent.registrationStatus = self.registrationStatus != nil ? Int16(self.registrationStatus!) : -1
        connectivityEvent.simUnlocked = simUnlocked
    }
}

/* For us, a Connectvivity Event is an event that states if the baseband is connected to a cell or not. */
struct ConnectivityEventParser {
    static func isConnectivityEventPacket(qmi: PacketQMI?, ari: PacketARI?) -> Bool {
        if let qmi = qmi {
            guard let direction = qmi.direction else {
                return false
            }

            switch (CPTDirection(rawValue: direction), qmi.service, qmi.message) {
            case (.outgoing, Int16(PacketConstants.qmiConnectivityWDSService), Int32(PacketConstants.qmiConnectivityStartNetworkMessageId)),
                (.outgoing, Int16(PacketConstants.qmiConnectivityWDSService), Int32(PacketConstants.qmiConnectivityStopNetworkMessageId)),
                (.outgoing, Int16(PacketConstants.qmiConnectivityDMSService), Int32(PacketConstants.qmiConnectivitySetOperatingModeMessageId)),
                (.ingoing, Int16(PacketConstants.qmiConnectivityUIMService), Int32(PacketConstants.qmiConnectivityCardStatusMessageId)):
                return true
            default:
                return false
            }
        } else if let ari = ari {
            return switch (ari.group, ari.type) {
            case (Int16(PacketConstants.ariGroupNetPlmn), Int32(PacketConstants.ariTypeRegistrationInfo)),
                (Int16(PacketConstants.ariGroupBsp), Int32(PacketConstants.ariTypeCsiModeSet)),
                (Int16(PacketConstants.ariGroupSimAccess), Int32(PacketConstants.ariTypeGetSimData)):
                true
            default:
                false
            }
        }
        return false
    }

    /*
     We use three different QMI packet types to determine connectivity events:
     1) "Start Network" packets: SIM-specific
     2) "Stop Network" packets: SIM-specific
     3) "Set Operating Mode" packets: Hardware-related. Just triggered with Airplane Mode.
     */
    func parseQmiPacket(_ data: Data, timestamp: Date, simSlot: UInt8) throws -> [ParsedConnectivityEvent] {
        let parsedPacket = try ParsedQMIPacket(nsData: data)

        if parsedPacket.transactionHeader.request {
            switch (parsedPacket.qmuxHeader.serviceId, parsedPacket.messageHeader.messageId) {
            case (PacketConstants.qmiConnectivityWDSService, PacketConstants.qmiConnectivityStartNetworkMessageId):
                return [parseQMIStartNetworkEvent(parsedPacket, timestamp: timestamp, simSlot: simSlot)]
            case (PacketConstants.qmiConnectivityWDSService, PacketConstants.qmiConnectivityStopNetworkMessageId):
                return [parseQMIStopNetworkEvent(parsedPacket, timestamp: timestamp, simSlot: simSlot)]
            case (PacketConstants.qmiConnectivityDMSService, PacketConstants.qmiConnectivitySetOperatingModeMessageId):
                return [try parseQMISetOperatingModeEvent(parsedPacket, timestamp: timestamp, simSlot: simSlot)]
            default:
                throw ConnectivityParserError.invalidMessage
            }
        } else if parsedPacket.transactionHeader.indication {
            if parsedPacket.qmuxHeader.serviceId == PacketConstants.qmiConnectivityUIMService
                && parsedPacket.messageHeader.messageId == PacketConstants.qmiConnectivityCardStatusMessageId {
                return try parseQMICardStatusEvent(parsedPacket, timestamp: timestamp)
            } else {
                throw ConnectivityParserError.invalidMessage
            }
        } else {
            throw ConnectivityParserError.invalidDirection
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

    /*
    * Manually, we found that Card State corresponds to
    * 1 => SIM inserted
    * 2 => SIM tray inserted without SIM
    * 3 => SIM tray removed
    * There is also an response message with the Card Status TLV. We might parse it in future.
    * There is also an "ExtendedCardStatus" TLV. We might parse it in future.
    */
    private func parseQMICardStatusEvent(_ parsedPacket: ParsedQMIPacket, timestamp: Date) throws -> [ParsedConnectivityEvent] {
        guard let cardStatusTlv = parsedPacket.findTlvValue(type: PacketConstants.qmiConnectivityCardStatusTlvType) else {
            throw ConnectivityParserError.missingRequiredTlv
        }

        var events: [ParsedConnectivityEvent] = []
        let data = BinaryData(data: cardStatusTlv.data, bigEndian: false)
        let _: UInt16 = try data.get(0) // Index GW Primary
        let _: UInt16 = try data.get(2) // Index 1x Primary
        let _: UInt16 = try data.get(4) // Index GW Secondary
        let _: UInt16 = try data.get(6) // Index 1x Secondary
        let cardsCount: UInt8 = try data.get(8) // Cards Array Count
        var i = 9
        for card in 0..<cardsCount {
            let cardState: UInt8 = try data.get(i) // Card State
            let _: UInt8 = try data.get(i+1) // UPIN State
            let _: UInt8 = try data.get(i+2) // UPIN Retries
            let _: UInt8 = try data.get(i+3) // UPUK Retries
            let _: UInt8 = try data.get(i+4) // Error code
            let appCount: UInt8 = try data.get(i+5) // Applications Array Count
            i += 6
            var unlocked = false
            for _ in 0..<appCount {
                let appType: UInt8 = try data.get(i) // Type
                let _: UInt8 = try data.get(i+1) // State
                let appPersonalization: UInt8 = try data.get(i+2) // Personalization State
                if appType == 2 && appPersonalization > 0 {
                    unlocked = true
                }
                let _: UInt8 = try data.get(i+3) // Personalization Feature
                let _: UInt8 = try data.get(i+4) // Personalization Retries
                let _: UInt8 = try data.get(i+5) // Personalization Unblock Retries
                let idCount: UInt8 = try data.get(i+6) // Application Identifier Value Array Count
                i += 7 + Int(idCount) + 7
            }

            events.append(ParsedConnectivityEvent(active: cardState == 1, timestamp: timestamp, simSlot: card + 1, simUnlocked: unlocked))
        }

        return events
    }

    /*
     We use two different ARI packet types to determine connectivity events:
     1) "IBINetRegistrationInfoIndCb" packets: SIM-specific
     2) "CsiModeSetReq" packets: Hardware-related
     */
    func parseAriPacket(_ data: Data, timestamp: Date, simSlot: UInt8) throws -> ParsedConnectivityEvent {
        let parsedPacket = try ParsedARIPacket(data: data)

        switch (parsedPacket.header.group, parsedPacket.header.type) {
        case (PacketConstants.ariGroupNetPlmn, PacketConstants.ariTypeRegistrationInfo):
            return try parseAriRegistrationInfo(parsedPacket, timestamp: timestamp, simSlot: simSlot)
        case (PacketConstants.ariGroupBsp, PacketConstants.ariTypeCsiModeSet):
            return try parseAriCsiMode(parsedPacket, timestamp: timestamp, simSlot: simSlot)
        case (PacketConstants.ariGroupSimAccess, PacketConstants.ariTypeGetSimData):
            return try parseAriSimData(parsedPacket, timestamp: timestamp, simSlot: simSlot)
        default:
            throw ConnectivityParserError.invalidMessage
        }
    }

    /*
     See https://github.com/seemoo-lab/aristoteles
     ["IBINetRegistrationStatus"] = {
         [0] = "IBI_NET_REGISTRATION_STATUS_NORMAL_SERVICE",
         [1] = "IBI_NET_REGISTRATION_STATUS_FAILURE",
         [2] = "IBI_NET_REGISTRATION_STATUS_LIMITED_SERVICE",
         [3] = "IBI_NET_REGISTRATION_STATUS_NO_SERVICE",
         [4] = "IBI_NET_REGISTRATION_STATUS_AT_NOT_REGISTERED",
         [5] = "IBI_NET_REGISTRATION_STATUS_SERVICE_DISABLED",
         [6] = "IBI_NET_REGISTRATION_STATUS_SERVICE_DETACHED",
         [7] = "IBI_NET_REGISTRATION_STATUS_PS_EMERGENCY",
         [8] = "IBI_NET_REGISTRATION_STATUS_PS_EMERGENCY_LIMITED",
         [9] = "IBI_NET_REGISTRATION_STATUS_REGISTERED_SMS_ONLY",
         [10] = "IBI_NET_REGISTRATION_STATUS_REGISTRATION_IN_PROGRESS",
     },
     */
    func parseAriRegistrationInfo(_ parsedPacket: ParsedARIPacket, timestamp: Date, simSlot: UInt8) throws -> ParsedConnectivityEvent {
        guard let statusTlv = parsedPacket.findTlvValue(type: PacketConstants.ariRegistrationInfoTlvStatusType) else {
            throw ConnectivityParserError.missingRequiredTlv
        }

        let data = BinaryData(data: statusTlv.data, bigEndian: false)
        let status: UInt32 = try data.get(0)
        let active = ![3, 5, 6].contains(status)

        return ParsedConnectivityEvent(active: active, timestamp: timestamp, simSlot: simSlot, registrationStatus: UInt8(status))
    }

    /*
     See libBasebandCommandDrivers.dylib
     [0] = "Online"
     [1] = "LowPower", <- Used for Airplane mode
     [2] = "FactoryTest",
     [3] = "Offline",
     [4] = "Reset",
     [5] = "Shutdown",
     [6] = "CampOnly",
     [7] = "Stewie",
     The OpMode is converted for sending it to the baseband. The conversion depends on the radio vendor. We use the following mapping:
     0 -> 1, 1 -> 2, 2 -> 4, 3 -> 0, 4 -> 0, 5 -> 6, 6 -> 7

     Internally, also a sub-mode is handled: "Minimal", "Normal", "Airplane", "Calibration", "ProductionTest", "Alarm", "ChargeOnly", "ForcedSleep".
     */
    func parseAriCsiMode(_ parsedPacket: ParsedARIPacket, timestamp: Date, simSlot: UInt8) throws -> ParsedConnectivityEvent {
        guard let modeTlv = parsedPacket.findTlvValue(type: PacketConstants.ariTypeCsiModeSetTlvModeType) else {
            throw ConnectivityParserError.missingRequiredTlv
        }

        let data = BinaryData(data: modeTlv.data, bigEndian: false)
        let mode: UInt32 = try data.get(0)
        let active = ![0, 2, 6].contains(mode)

        return ParsedConnectivityEvent(active: active, timestamp: timestamp, simSlot: simSlot, basebandMode: UInt8(mode))
    }

    func parseAriSimData(_ parsedPacket: ParsedARIPacket, timestamp: Date, simSlot: UInt8) throws -> ParsedConnectivityEvent {
        guard let stateTlv = parsedPacket.findTlvValue(type: PacketConstants.ariTypeGetSimDataTlvState) else {
            throw ConnectivityParserError.missingRequiredTlv
        }

        let data = BinaryData(data: stateTlv.data, bigEndian: false)
        let state: UInt32 = try data.get(0)
        let active = [1, 2, 4, 5].contains(state)

        return ParsedConnectivityEvent(active: active, timestamp: timestamp, simSlot: simSlot, simUnlocked: [4, 5].contains(state))
    }
}
