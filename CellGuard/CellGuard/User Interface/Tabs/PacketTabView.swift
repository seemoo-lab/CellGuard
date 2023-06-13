//
//  PacketTabView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 08.06.23.
//

import SwiftUI
import CoreData

struct PacketTabView: View {
    
    // TODO: Add divider for days (bold) & hours
    // TODO: Add calendar to quickly up to certain dates (& hours)
    // TODO: Add filter to search for specific properties
    // TODO: Use new list style
    
    // We have to use separate fetch request as the preview crashes a unified request
    @FetchRequest
    private var qmiPackets: FetchedResults<QMIPacket>
    
    @FetchRequest
    private var ariPackets: FetchedResults<ARIPacket>

    // TODO: Fetch packets in batches
    
    init() {
        // https://www.hackingwithswift.com/quick-start/swiftui/how-to-limit-the-number-of-items-in-a-fetch-request
        let qmiRequest: NSFetchRequest<QMIPacket> = QMIPacket.fetchRequest()
        qmiRequest.fetchLimit = 200
        qmiRequest.fetchBatchSize = 25
        qmiRequest.sortDescriptors = [NSSortDescriptor(keyPath: \QMIPacket.collected, ascending: false)]
        
        let ariRequest: NSFetchRequest<ARIPacket> = ARIPacket.fetchRequest()
        ariRequest.fetchLimit = 200
        ariRequest.fetchBatchSize = 25
        ariRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ARIPacket.collected, ascending: false)]
        
        self._qmiPackets = FetchRequest(fetchRequest: qmiRequest, animation: .easeOut)
        self._ariPackets = FetchRequest(fetchRequest: ariRequest, animation: .easeOut)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if (qmiPackets.isEmpty && ariPackets.isEmpty) {
                    Text("No packets collected so far. Is the tweak installed?")
                        .multilineTextAlignment(.center)
                        .padding()
                } else if (!qmiPackets.isEmpty) {
                    QMIPacketList(qmiPackets: qmiPackets)
                } else if (!ariPackets.isEmpty) {
                    ARIPacketList(ariPackets: ariPackets)
                } else {
                    // TODO: CHANGE!!!
                    Text("Warning: Only showing QMI packets for now")
                    QMIPacketList(qmiPackets: qmiPackets)
                }
            }
            .navigationTitle("Packets")
        }
    }
}

private struct QMIPacketList: View {
    let qmiPackets: FetchedResults<QMIPacket>
    
    var body: some View {
        // TODO: Improve performance (-> Decrease query speed)
        
        List(qmiPackets) { packet in
            NavigationLink {
                PacketQMIDetailsView(packet: packet)
            } label: {
                PacketCell(packet: packet)
            }
            
            /* if let thisDate = packet.collected, let lastDate = packet.las {
                let thisDate = Calendar.current.dateComponents([.day, .month, .year], from: packet.collected)
            } */
        }
        .listStyle(.insetGrouped)
    }
}

private struct ARIPacketList: View {
    let ariPackets: FetchedResults<ARIPacket>
    
    var body: some View {
        List(ariPackets) { packet in
            NavigationLink {
                PacketARIDetailsView(packet: packet)
            } label: {
                PacketCell(packet: packet)
            }
        }
        .listStyle(.insetGrouped)
    }
}

/* private struct MergedPacketList: View {
    private let packets: [Packet]
    
    init(qmiPackets: FetchedResults<QMIPacket>, ariPackets: FetchedResults<ARIPacket>) {
        self.packets = [qmiPackets.arr, List(ariPackets)].lazy.joined()
    }
    
    var body: some View {
        List(packets) { packet in
            NavigationLink {
                if let qmiPacket = packet as? QMIPacket {
                    PacketQMIDetailsView(packet: qmiPacket)
                } else if let ariPacket = packet as? ARIPacket {
                    PacketARIDetailsView(packet: ariPacket)
                }
                PacketARIDetailsView(packet: packet)
            } label: {
                PacketCell(packet: packet)
            }
        }
    }
} */

struct PacketTabView_Previews: PreviewProvider {
    static var previews: some View {
        PacketTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
