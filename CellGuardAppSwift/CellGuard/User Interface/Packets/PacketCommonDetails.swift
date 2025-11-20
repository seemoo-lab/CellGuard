//
//  CommonPacketDetailsView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 09.06.23.
//

import Foundation
import SwiftUI

struct PacketDetailsSection: View {
    var packet: any Packet
    var data: Data

    var body: some View {
        Section(header: Text("Packet")) {
            DetailsRow("Protocol", packet.proto)
            DetailsRow("SIM Slot", packet.simSlotID == 0 ? "None" : String(packet.simSlotID))
            DetailsRow("Direction", packet.direction ?? "???")
            DetailsRow("Timestamp", date: packet.collected)
            if let sysdiagnose = packet.sysdiagnose {
                ListNavigationLink(value: NavObjectId(object: sysdiagnose)) {
                    SysdiagnoseCell(sysdiagnose: sysdiagnose, showArchiveIdentifier: false)
                }
            }
            DetailsRow("Size", bytes: data.count)
            DetailsRow("Data", data: data)
        }
    }
}
