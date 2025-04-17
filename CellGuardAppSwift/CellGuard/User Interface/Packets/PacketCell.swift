//
//  PacketCell.swift
//  CellGuard
//
//  Created by Lukas Arnold on 09.06.23.
//

import SwiftUI

struct PacketCell: View {

    let packet: any Packet
    let customInfo: Text?

    init(packet: any Packet, customInfo: Text? = nil) {
        self.packet = packet
        self.customInfo = customInfo
    }

    var body: some View {
        VStack {
            if let qmiPacket = packet as? PacketQMI {
                PacketCellQMIBody(packet: qmiPacket)
            } else if let ariPacket = packet as? PacketARI {
                PacketCellARIBody(packet: ariPacket)
            }
            if let customInfo = customInfo {
                PacketCellCustomInfo(info: customInfo)
            }
            PacketCellFooter(packet: packet)
        }
    }
}

private struct PacketCellQMIBody: View {

    let packet: PacketQMI

    var body: some View {
        let definitions = QMIDefinitions.shared
        let service = definitions.services[UInt8(packet.service)]
        let message = packet.indication ? service?.indications[UInt16(packet.message)] : service?.messages[UInt16(packet.message)]

        VStack {
            HStack {
                if packet.direction == CPTDirection.ingoing.rawValue {
                    Image(systemName: "arrow.right")
                } else if packet.direction == CPTDirection.outgoing.rawValue {
                    Image(systemName: "arrow.left")
                }

                // We can combine text views using the + operator
                // See: https://www.hackingwithswift.com/quick-start/swiftui/how-to-combine-text-views-together
                Text("\(packet.proto) \(packet.indication ? "Indication" : "Message")")
                    .bold()
                + Text(" (\(service?.shortName ?? hexString(packet.service))) ")
                + grayText(bytes: packet.data?.count ?? 0)

                Spacer()
            }
            HStack {
                Text(message?.name ?? hexString(packet.message))
                Spacer()
            }
        }
    }

}

private struct PacketCellARIBody: View {

    let packet: PacketARI

    var body: some View {
        let definitions = ARIDefinitions.shared
        let group = definitions.groups[UInt8(packet.group)]
        let type = group?.types[UInt16(packet.type)]

        VStack {
            HStack {
                if packet.direction == CPTDirection.ingoing.rawValue {
                    Image(systemName: "arrow.right")
                } else if packet.direction == CPTDirection.outgoing.rawValue {
                    Image(systemName: "arrow.left")
                }

                Text("\(packet.proto)")
                    .bold()
                + Text(" (\(group?.name ?? hexString(packet.group))) ")
                + grayText(bytes: packet.data?.count ?? 0)

                Spacer()
            }
            HStack {
                Text(type?.name ?? hexString(packet.type))
                Spacer()
            }
        }
    }

}

private struct PacketCellCustomInfo: View {

    let info: Text

    var body: some View {
        VStack {
            HStack {
                info
                Spacer()
            }
        }
    }

}

private struct PacketCellFooter: View {

    let packet: any Packet

    var body: some View {
        HStack {
            Text(fullMediumDateTimeFormatter.string(from: packet.collected ?? Date(timeIntervalSince1970: 0)))
                .font(.system(size: 14))
                .foregroundColor(.gray)
            Spacer()
        }
    }
}

private func hexString(_ hex: any BinaryInteger) -> String {
    return "0x\(String(hex, radix: 16, uppercase: true))"
}

private func grayText(_ text: String) -> Text {
    return Text("\(text)")
        .foregroundColor(.gray)
}

private func grayText(bytes: Int) -> Text {
    // 0x2009 is a half-width space Unicode character
    // See: https://www.compart.com/en/unicode/U+2009
    // See: https://stackoverflow.com/a/27272056
    return grayText("\(bytes)\u{2009}B")
}

private func grayText(hex: any BinaryInteger) -> Text {
    return grayText(hexString(hex))
}

struct PacketCell_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let packets = PersistencePreview.packets(context: context).map { PacketContainer(packet: $0) }

        NavigationView {
            List {
                ForEach(packets) { packet in
                    NavigationLink {
                        Text("Hello")
                    } label: {
                        PacketCell(packet: packet.packet)
                            .environment(\.managedObjectContext, context)
                    }
                }
            }
        }
    }
}
