//
//  PacketDetailsView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 09.06.23.
//

import SwiftUI

struct PacketQMIDetailsView: View {
    let packet: PacketQMI

    var body: some View {
        List {
            if let data = packet.data {
                if let parsed = try? ParsedQMIPacket(nsData: data) {
                    PacketQMIDetailsList(packet: packet, data: data, parsed: parsed)
                } else {
                    Text("Failed to parse the packet's binary data:")
                }
            } else {
                Text("Failed to get the packet's binary data.")
            }
        }
        .navigationTitle("QMI Packet")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
    }
}

private struct PacketQMIDetailsList: View {

    let packet: PacketQMI
    let data: Data
    let parsed: ParsedQMIPacket

    var body: some View {
        let serviceId = parsed.qmuxHeader.serviceId
        let messageId = parsed.messageHeader.messageId

        let definitions = QMIDefinitions.shared
        let serviceDef = definitions.services[serviceId]
        let messageDef = parsed.transactionHeader.indication ? serviceDef?.indications[messageId] : serviceDef?.messages[messageId]

        Group {
            Section(header: Text("Packet")) {
                PacketDetailsRow("Protocol", packet.proto)
                PacketDetailsRow("SIM Slot", packet.simSlotID == 0 ? "None" : String(packet.simSlotID))
                PacketDetailsRow("Direction", packet.direction ?? "???")
                PacketDetailsRow("Timestamp", date: packet.collected)
                PacketDetailsRow("Size", bytes: data.count)
                PacketDetailsDataRow("Data", data: data)
            }
            Section(header: Text("QMux Header")) {
                PacketDetailsRow("Packet Length", bytes: Int(parsed.qmuxHeader.length))
                PacketDetailsRow("Flag", hex: parsed.qmuxHeader.flag)
                PacketDetailsRow("Service ID", hex: parsed.qmuxHeader.serviceId)
                if let serviceDef = serviceDef {
                    PacketDetailsRow("Service Short Name", serviceDef.shortName)
                    PacketDetailsRow("Service Name", serviceDef.longName)
                }
                PacketDetailsRow("Client ID", hex: parsed.qmuxHeader.clientId)
            }
            Section(header: Text("Transaction Header")) {
                PacketDetailsRow("Compound", bool: parsed.transactionHeader.compound)
                PacketDetailsRow("Response", bool: parsed.transactionHeader.response)
                PacketDetailsRow("Indication", bool: parsed.transactionHeader.indication)
                PacketDetailsRow("Transaction ID", hex: parsed.transactionHeader.transactionId)
            }
            Section(header: Text("Message Header")) {
                PacketDetailsRow("Message ID", hex: parsed.messageHeader.messageId)
                if let messageDef = messageDef {
                    PacketDetailsRow("Message Name", messageDef.name)
                }
                PacketDetailsRow("Message Length", bytes: Int(parsed.messageHeader.messageLength))
            }

            ForEach(parsed.tlvs, id: \.type) { tlv in
                Section(header: Text("TLV")) {
                    PacketDetailsRow("ID", hex: tlv.type)
                    PacketDetailsRow("Length", bytes: Int(tlv.length))
                    PacketDetailsDataRow("Data", data: tlv.data)
                }
            }

            // TODO: Include QMIContentParser, e.g., for signal strength, or use libqmi definitions to parse the packet on-the-fly
        }
    }

}

struct PacketQMIDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let packets = PersistencePreview.packets(context: context)

        NavigationView {
            if let packet = packets[0] as? PacketQMI {
                PacketQMIDetailsView(packet: packet)
            }
        }
        .environment(\.managedObjectContext, context)
    }
}
