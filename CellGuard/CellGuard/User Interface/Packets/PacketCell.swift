//
//  PacketCell.swift
//  CellGuard
//
//  Created by Lukas Arnold on 09.06.23.
//

import SwiftUI

struct PacketCell: View {
    
    let packet: Packet
    
    var body: some View {
        VStack {
            PacketCellHeader(packet: packet)
            if let qmiPacket = packet as? QMIPacket {
                PacketCellQMIBody(packet: qmiPacket)
            } else if let ariPacket = packet as? ARIPacket {
                PacketCellARIBody(packet: ariPacket)
            }
            PacketCellFooter(packet: packet)
        }
    }
}

private struct PacketCellHeader: View {
    
    let packet: Packet
    
    var body: some View {

        
        HStack {
            if (packet.direction == CPTDirection.ingoing.rawValue) {
                // tray.and.arrow.down
                Image(systemName: "arrow.right")
            } else if (packet.direction == CPTDirection.outgoing.rawValue) {
                // tray.and.arrow.up
                Image(systemName: "arrow.left")
            }
            
            // We can combine text views using the + operator
            // See: https://www.hackingwithswift.com/quick-start/swiftui/how-to-combine-text-views-together
            Text(headerString)
                .bold()
            + GrayText(bytes: packet.data?.count ?? 0)
            
            Spacer()
        }
    }
    
    var headerString: String {
        var headerString = packet.proto ?? "???"
        
        if let qmiPacket = packet as? QMIPacket {
            headerString += ": \(qmiPacket.indication ? "Indication" : "Message")"
        }
        
        return headerString
    }
    
}

private func hexString(_ value: any BinaryInteger) -> String {
    return "0x\(String(value, radix: 16))"
}

private struct PacketCellQMIBody: View {
    
    let packet: QMIPacket
    
    var body: some View {
        let definitions = QMIDefinitions.shared
        let service = definitions.services[UInt8(packet.service)]
        let message = packet.indication ? service?.indications[UInt16(packet.message)] : service?.messages[UInt16(packet.message)]
        
        VStack {
            HStack {
                // Image(systemName: "books.vertical")
                Text(service?.longName ?? "???")
                + GrayText(hex: packet.service)
                Spacer()
            }
            HStack {
                // Image(systemName: "book")
                Text(message?.name ?? "???")
                + GrayText(hex: packet.message)
                Spacer()
            }
        }
    }
    
}

private struct PacketCellARIBody: View {
    
    let packet: ARIPacket
    
    var body: some View {
        let definitions = ARIDefinitions.shared
        let group = definitions.groups[UInt8(packet.group)]
        let type = group?.types[UInt16(packet.type)]

        VStack {
            HStack {
                // Image(systemName: "books.vertical")
                Text(group?.name ?? "???")
                + GrayText(hex: packet.group)
                Spacer()
            }
            HStack {
                // Image(systemName: "book")
                Text(type?.name ?? "???")
                + GrayText(hex: packet.type)
                Spacer()
            }
        }
    }
    
}

private struct PacketCellFooter: View {
    
    let packet: Packet
    
    var body: some View {
        HStack {
            // Image(systemName: "clock")
            Text(fullMediumDateTimeFormatter.string(from: packet.collected ?? Date(timeIntervalSince1970: 0)))
                .font(.system(size: 14))
                .foregroundColor(.gray)
            Spacer()
        }
    }
}

private func GrayText(_ text: String) -> Text {
    return Text("  \(text)")
        .foregroundColor(.gray)
}

private func GrayText(bytes: Int) -> Text {
    // 0x2009 is a half-width space Unicode character
    // See: https://www.compart.com/en/unicode/U+2009
    // See: https://stackoverflow.com/a/27272056
    return GrayText("\(bytes)\u{2009}B")
}

private func GrayText(hex: any BinaryInteger) -> Text {
    return GrayText("0x\(String(hex, radix: 16))")
}

struct PacketCell_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let packets = PersistencePreview.packets(context: context)
        
        NavigationView {
            List {
                ForEach(packets) { packet in
                    NavigationLink {
                        Text("Hello")
                    } label: {
                        PacketCell(packet: packet)
                            .environment(\.managedObjectContext, context)
                    }
                }
            }
        }
    }
}
