//
//  PacketARIDetailsView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 09.06.23.
//

import SwiftUI
import NavigationBackport

struct PacketARIDetailsView: View {
    let packet: PacketARI

    var body: some View {
        List {
            if let data = packet.data {
                if let parsed = try? ParsedARIPacket(data: data) {
                    PacketARIDetailsList(packet: packet, data: data, parsed: parsed)
                } else {
                    Text("Failed to parse the packet's binary data")
                }
            } else {
                Text("Failed to get the packet's binary data.")
            }

        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("ARI Packet")
    }
}

private struct PacketARIDetailsList: View {

    let packet: PacketARI
    let data: Data
    let parsed: ParsedARIPacket

    var body: some View {
        let definitions = ARIDefinitions.shared
        let groupDef = definitions.groups[parsed.header.group]
        let typeDef = groupDef?.types[parsed.header.type]

        return Group {
            PacketDetailsSection(packet: packet, data: data)
            Section(header: Text("ARI Header")) {
                DetailsRow("Group ID", hex: parsed.header.group)
                if let groupDef = groupDef {
                    DetailsRow("Group Name", groupDef.name)
                }
                DetailsRow("Sequence Number", hex: parsed.header.sequenceNumber)
                DetailsRow("Length", hex: parsed.header.length)
                DetailsRow("Type ID", hex: parsed.header.type)
                if let typeDef = typeDef {
                    DetailsRow("Type Name", typeDef.name)
                }
                DetailsRow("Transaction", hex: parsed.header.transaction)
                DetailsRow("Acknowledgement", bool: parsed.header.acknowledgement)
            }
            ForEach(parsed.tlvs, id: \.type) { tlv in
                PacketARIDetailsTLVSection(tlv: tlv, typeDef: typeDef)
            }

            // TODO: Include ARIContentParser, e.g., for signal strength, or use libqmi definitions to parse the packet on-the-fly
        }
    }

}

private struct PacketARIDetailsTLVSection: View {

    let tlv: AriTlv
    let tlvDef: ARIDefinitionTLV?

    init(tlv: AriTlv, typeDef: ARIDefinitionType?) {
        self.tlv = tlv
        self.tlvDef = typeDef?.tlvs[tlv.type]
    }

    var body: some View {
        Section(header: Text("TLV")) {
            DetailsRow("ID", hex: tlv.type)
            DetailsRow("Version", hex: tlv.version)
            if let tlvDef = tlvDef {
                DetailsRow("Name", tlvDef.name)
                DetailsRow("Codec", tlvDef.codecName)
            }
            DetailsRow("Length", bytes: Int(tlv.length))
            DetailsRow("Data", data: tlv.data)
        }
    }

}

struct PacketARIDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let packets = PersistencePreview.packets(context: context)

        NBNavigationStack {
            if let packet = packets[3] as? PacketARI {
                PacketARIDetailsView(packet: packet)
            }
        }
        .environment(\.managedObjectContext, context)
    }
}
