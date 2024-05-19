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
    func filter(qmi packet: PacketQMI) -> Bool {
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
    
    /// Filters ARI packets to decide if they should be included in the study.
    /// Returns true if the packet should be included.
    func filter(ari packet: PacketARI) -> Bool {
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
    
}
