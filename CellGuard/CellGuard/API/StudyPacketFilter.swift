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
        let indication = packet.indication
        let service = packet.service
        let message = packet.message
        
        // Packet Content Documentation: 
        // - https://dev.seemoo.tu-darmstadt.de/apple/libqmi/-/tree/ios-message-ids/data/ios?ref_type=heads
        // - https://dev.seemoo.tu-darmstadt.de/apple/iphone-qmi-wireshark/-/blob/main/dissector/qmi_services.py?ref_type=heads
        
        // Removes all packets of the "Wireless Messaging Service"
        if service == 0x05 {
            return false
        }
        
        // TODO: Filter more packet types, i.e, those that include IMEI
        
        // By default we include all packets
        return true
    }
    
    /// Strips PPI from the QMI packet and marks it as stripped.
    /// Returns the stripped data.
    static func strip(qmi packet: Data) throws -> Data {
        let parsed = try ParsedQMIPacket(nsData: packet)
        
        let qmuxHeader = parsed.qmuxHeader
        let messageHeader = parsed.messageHeader
        let txHeader = parsed.transactionHeader
        
        // Modifying the flag to signal that we removed PPI from this packet
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
        
        // Removes all packets from the group "04_sms"
        if group == 4 {
            return false
        }
        
        // TODO: Filter more packet types
        
        // By default we include all packets
        return true
    }
    
    /// Strips PPI from the ARI packet and marks it as stripped.
    /// Returns the stripped data.
    static func strip(ari packet: Data) throws -> Data {
        let parsed = try ParsedARIPacket(data: packet)
        let header = parsed.header
        
        // Adding a dummy TLV to signal that we removed PPI from this packet
        return try ParsedARIPacket(
            group: header.group, type: header.type,
            transaction: header.transaction, sequenceNumber: header.sequenceNumber,
            acknowledgement: header.acknowledgement,
            tlvs: [ARITLV(type: 1 << 10, version: 0, data: Data())]
        ).write()
    }
    
}
