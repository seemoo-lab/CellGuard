//
//  StudyPacketFilter.swift
//  CellGuard
//
//  Created by Lukas Arnold on 14.05.24.
//

import Foundation

struct StudyPacketFilter {
    
    /// Filters QMI packets to decide if they should be included in the study.
    /// Returns true if the packet should be included.
    static func filter(qmi packet: PacketQMI) -> Bool {
        // Packet Content Documentation:
        // - https://dev.seemoo.tu-darmstadt.de/apple/libqmi/-/tree/ios-message-ids/data/ios?ref_type=heads
        // - https://dev.seemoo.tu-darmstadt.de/apple/iphone-qmi-wireshark/-/blob/main/dissector/qmi_services.py?ref_type=heads
        
        // How to find packets with PII:
        // - Search libqmi for "personal-info"
        // - Search Wireshark traces for personal data, e.g. using "frame contains aa:aa:aa"
        
        let indication = packet.indication
        let service = packet.service
        let message = packet.message
        
        // WDS
        if service == 0x01 {
            // Start Network
            if message == 0x0020 && indication == false {
                return false
            }
            // Create Profile
            if message == 0x0027 && indication == false {
                return false
            }
            // Modify Profile
            if message == 0x0028 && indication == false {
                return false
            }
            // Get Profile Settings
            if message == 0x002B && indication == false {
                return false
            }
            // Get Default Settings
            if message == 0x002C && indication == false {
                return false
            }
            // Get Current Settings
            if message == 0x002D && indication == false {
                return false
            }
            // Swi Create Profile Indexed
            if message == 0x5558 && indication == false {
                return false
            }
        }
        
        // DMS
        if service == 0x02 {
            // Get IDs (including IMEI)
            if message == 0x0025 && indication == false {
                return false
            }
            // UIM Set PIN Protection
            if message == 0x0027 && indication == false {
                return false
            }
            // UIM Verify PIN
            if message == 0x0028 && indication == false {
                return false
            }
            // UIM Unblock PIN
            if message == 0x0029 && indication == false {
                return false
            }
            // Activate Manual
            if message == 0x0033 && indication == false {
                return false
            }
            // Set User Lock State
            if message == 0x0035 && indication == false {
                return false
            }
            // UIM Get ICCID
            if message == 0x003C && indication == false {
                return false
            }
            // UIM Get IMSI
            if message == 0x0043 && indication == false {
                return false
            }
        }
        
        // NAS
        if service == 0x03 {
            // Send WiFi Network Info
            if message == 0x5562 && indication == false {
                return false
            }
        }
        
        // WMS
        if service == 0x05 {
            // Event Report
            if message == 0x0001 && indication == true {
                return false
            }
            // Raw Send
            if message == 0x0020 && indication == false {
                return false
            }
            // Raw Write
            if message == 0x0021 && indication == false {
                return false
            }
            // Raw Read
            if message == 0x0022 && indication == false {
                return false
            }
        }
        
        // PDS
        if service == 0x06 {
            // For now we're don't collect any packets from the service as they might contain location data,
            // are quite frequent on jailbroken devices, and are relatively big.
            return false
        }
        
        // VS
        if service == 0x09 {
            // Dial Call
            if message == 0x0020 && indication == false {
                return false
            }
            // All Call Status
            if message == 0x002E && indication == true {
                return false
            }
            // Get All Call Info
            if message == 0x002F && indication == false {
                return false
            }
            // Set Call Barring Password
            if message == 0x0035 && indication == false {
                return false
            }
            // Originate USSD
            if message == 0x003A && indication == false {
                return false
            }
            // Answer USSD
            if message == 0x003B && indication == false {
                return false
            }
            // USSD
            if message == 0x003E && indication == true {
                return false
            }
            // Originate USSD No Wait
            if message == 0x0043 && indication == false {
                return false
            }
            // Burst DTMF
            if message == 0x0028 && indication == false {
                return false
            }
        }
        
        // UIM
        if service == 0x0B {
            // Read Transparent
            if message == 0x0020 && indication == false {
                return false
            }
            // Read Record
            if message == 0x0021 && indication == false {
                return false
            }
            // Write Transparent
            if message == 0x0022 && indication == false {
                return false
            }
            // Set PIN Protection
            if message == 0x0025 && indication == false {
                return false
            }
            // Verify PIN
            if message == 0x0026 && indication == false {
                return false
            }
            // Unblock PIN
            if message == 0x0027 && indication == false {
                return false
            }
            // Change PIN
            if message == 0x0028 && indication == false {
                return false
            }
            // Depersonalization
            if message == 0x0029 && indication == false {
                return false
            }
            // Authenticate
            if message == 0x0034 && indication == false {
                return false
            }
            // Get Slot Status
            if message == 0x0047 && indication == false {
                return false
            }
            // Slot Status
            if message == 0x0048 && indication == true {
                return false
            }
            // Remote Unlock
            if message == 0x005D && indication == false {
                return false
            }
        }
        
        // MS
        if service == 0x52 {
            // Session Initialize (SIP)
            if message == 0x0041 && indication == false {
                return false
            }
            // Service RCTP Reports (SIP)
            if message == 0x0052 && indication == true {
                return false
            }
        }
        
        // CAT
        if service == 0x0A {
            // Send Decoded Envelope
            if message == 0x0025 && indication == false {
                return false
            }
        }
        
        // By default we include all packets
        return true
    }
    
    /// Strips PII from the QMI packet and marks it as stripped.
    /// Returns the stripped data.
    static func strip(qmi packet: Data) throws -> Data {
        let parsed = try ParsedQMIPacket(nsData: packet)
        
        let qmuxHeader = parsed.qmuxHeader
        let messageHeader = parsed.messageHeader
        let txHeader = parsed.transactionHeader
        
        // Modifying the flag to signal that we removed PII from this packet
        return try ParsedQMIPacket(
            flag: qmuxHeader.flag + 1, serviceId: qmuxHeader.serviceId, clientId: qmuxHeader.clientId,
            messageId: messageHeader.messageId,
            compound: txHeader.compound, indication: txHeader.indication, response: txHeader.response, transactionId: txHeader.transactionId,
            tlvs: []
        ).write()
    }
    
    /// Filters ARI packets to decide if they should be included in the study.
    /// Returns true if the packet should be included.
    static func filter(ari packet: PacketARI) -> Bool {
        let group = packet.group
        let type = packet.type
        
        // Packet Content Documentation: 
        // - https://github.com/seemoo-lab/aristoteles/blob/master/types/structure/libari_dylib.lua
        
        // 01_bsp
        if group == 1 {
            // CsiMsCpsReadImeiRspCb (513)
            if type == 513 {
                return false
            }
        }
        
        // Removes all packets from the group "02_cs"
        if group == 2 {
            return false
        }
        
        // Removes all packets from the group "04_sms"
        if group == 4 {
            return false
        }
        
        // Removes all packets from the group "12_sim_sec"
        if group == 12 {
            return false
        }
        
        // Removes all packets from the group "14_sim_pb"
        if group == 14 {
            return false
        }
        
        // Removes all packets from the group "16_call_cs_voims"
        if group == 16 {
            return false
        }
        
        // Removes all packets from the group "19_cls"
        if group == 19 {
            return false
        }
        
        // Removes all packets from the group "50_ibi_vinyl"
        if group == 50 {
            return false
        }
        
        // By default we include all packets
        return true
    }
    
    /// Strips PII from the ARI packet and marks it as stripped.
    /// Returns the stripped data.
    static func strip(ari packet: Data) throws -> Data {
        let parsed = try ParsedARIPacket(data: packet)
        let header = parsed.header
        
        // Adding a dummy TLV to signal that we removed PII from this packet
        return try ParsedARIPacket(
            group: header.group, type: header.type,
            transaction: header.transaction, sequenceNumber: header.sequenceNumber,
            acknowledgement: header.acknowledgement,
            tlvs: [ARITLV(type: 1 << 10, version: 0, data: Data())]
        ).write()
    }
    
}
