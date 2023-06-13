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
    
    @State private var filter: PacketFilterSettings = PacketFilterSettings()
    @State private var isShowingFilterView = false
    
    var body: some View {
        NavigationView {
            VStack {
                // A workaround for the problem that the view repeatedly opens on iOS 14.
                // Using this workaround we can effectively treat the view as a sheet which stores its open state using a @State variable.
                // See: https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-programmatic-navigation-in-swiftui
                // See:
                NavigationLink(isActive: $isShowingFilterView) {
                    PacketFilterView(settings: filter) { settings in
                        self.filter = settings
                    }
                } label: {
                    EmptyView()
                }
                FilteredPacketView(filter: filter)
            }
            .navigationTitle("Packets")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingFilterView = true
                    } label: {
                        // Starting with iOS 15: line.3.horizontal.decrease.circle
                        Image(systemName: "line.horizontal.3.decrease.circle")
                    }
                }
            }
        }
    }
}

private struct FilteredPacketView: View {
    
    // We have to use separate fetch request as the preview crashes for a unified request
    @FetchRequest
    private var qmiPackets: FetchedResults<QMIPacket>
    
    @FetchRequest
    private var ariPackets: FetchedResults<ARIPacket>
    
    private let filter: PacketFilterSettings
        
    init(filter: PacketFilterSettings) {
        self.filter = filter
        
        // https://www.hackingwithswift.com/quick-start/swiftui/how-to-limit-the-number-of-items-in-a-fetch-request
        let qmiRequest: NSFetchRequest<QMIPacket> = QMIPacket.fetchRequest()
        qmiRequest.fetchBatchSize = 25
        qmiRequest.sortDescriptors = [NSSortDescriptor(keyPath: \QMIPacket.collected, ascending: false)]
        filter.applyTo(qmi: qmiRequest)
        
        let ariRequest: NSFetchRequest<ARIPacket> = ARIPacket.fetchRequest()
        ariRequest.fetchBatchSize = 25
        ariRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ARIPacket.collected, ascending: false)]
        filter.applyTo(ari: ariRequest)
        
        self._qmiPackets = FetchRequest(fetchRequest: qmiRequest, animation: .easeOut)
        self._ariPackets = FetchRequest(fetchRequest: ariRequest, animation: .easeOut)
    }
    
    var body: some View {
        if filter.proto == .qmi {
            if qmiPackets.isEmpty {
                Text("No packets match your search criteria.")
            } else {
                QMIPacketList(qmiPackets: qmiPackets)
            }
        } else {
            if ariPackets.isEmpty {
                Text("No packets match your search criteria.")
            } else {
                ARIPacketList(ariPackets: ariPackets)
            }
        }
    }
}

private struct QMIPacketList: View {
    let qmiPackets: FetchedResults<QMIPacket>
    
    var body: some View {
        List(qmiPackets) { packet in
            NavigationLink {
                PacketQMIDetailsView(packet: packet)
            } label: {
                PacketCell(packet: packet)
            }
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

struct PacketTabView_Previews: PreviewProvider {
    static var previews: some View {
        PacketTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
