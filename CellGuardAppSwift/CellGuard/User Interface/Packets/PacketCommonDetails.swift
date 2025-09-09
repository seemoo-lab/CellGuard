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
                    SysdiagnoseCell(sysdiagnose: sysdiagnose)
                }
            }
            DetailsRow("Size", bytes: data.count)
            PacketDetailsDataRow("Data", data: data)
        }
    }
}

struct PacketDetailsDataRow: View {

    let description: String
    let hexString: String

    init(_ description: String, data: Data) {
        self.description = description
        self.hexString = data
            .map { String($0, radix: 16, uppercase: true) }
            .map { $0.count < 2 ? "0\($0)" : $0 }
            .joined(separator: " ")
    }

    var body: some View {
        VStack {
            HStack {
                Text(description)
                Spacer()
            }
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0))
            HStack {
                Text(hexString)
                    .font(Font(UIFont.monospacedSystemFont(ofSize: UIFont.systemFontSize, weight: .regular)))
                Spacer()
            }
        }
    }
}
