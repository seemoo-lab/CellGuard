//
//  PacketDetailsView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 09.06.23.
//

import SwiftUI
import NavigationBackport

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
            PacketDetailsSection(packet: packet, data: data)
            Section(header: Text("QMux Header")) {
                DetailsRow("Packet Length", bytes: Int(parsed.qmuxHeader.length))
                DetailsRow("Flag", hex: parsed.qmuxHeader.flag)
                DetailsRow("Service ID", hex: parsed.qmuxHeader.serviceId)
                if let serviceDef = serviceDef {
                    DetailsRow("Service Short Name", serviceDef.shortName)
                    DetailsRow("Service Name", serviceDef.longName)
                }
                DetailsRow("Client ID", hex: parsed.qmuxHeader.clientId)
            }
            Section(header: Text("Transaction Header")) {
                DetailsRow("Compound", bool: parsed.transactionHeader.compound)
                DetailsRow("Response", bool: parsed.transactionHeader.response)
                DetailsRow("Indication", bool: parsed.transactionHeader.indication)
                DetailsRow("Transaction ID", hex: parsed.transactionHeader.transactionId)
            }
            Section(header: Text("Message Header")) {
                DetailsRow("Message ID", hex: parsed.messageHeader.messageId)
                if let messageDef = messageDef {
                    DetailsRow("Message Name", messageDef.name)
                }
                DetailsRow("Message Length", bytes: Int(parsed.messageHeader.messageLength))
            }

            ForEach(parsed.tlvs, id: \.type) { tlv in
                Section(header: Text("TLV")) {
                    DetailsRow("ID", hex: tlv.type)
                    DetailsRow("Length", bytes: Int(tlv.length))
                    DetailsRow("Data", data: tlv.data)
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

        NBNavigationStack {
            if let packet = packets[0] as? PacketQMI {
                PacketQMIDetailsView(packet: packet)
            }
        }
        .environment(\.managedObjectContext, context)
    }
}
