//
//  PacketTabView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 08.06.23.
//

import CoreData
import SwiftUI
import OSLog

struct PacketTabView: View {
    
    // TODO: Add divider for days (bold) & hours
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: PacketTabView.self)
    )
    
    @AppStorage(UserDefaultsKeys.appMode.rawValue) private var appMode: DataCollectionMode = .none
    
    @State private var filter: PacketFilterSettings = PacketFilterSettings()
    @State private var isShowingFilterView = false
    
    var body: some View {
        // TODO: Store filter settings across different app executions?
        NavigationView {
            VStack {
                // A workaround for that the NavigationLink on iOS does not respect the isShowingFilterView variable if it's embedded into a ToolbarItem.
                // See: https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-programmatic-navigation-in-swiftui
                NavigationLink(isActive: $isShowingFilterView) {
                    PacketFilterView(settingsBound: $filter) {
                        isShowingFilterView = false
                    }
                } label: {
                    EmptyView()
                }
                FilteredPacketView(filter: filter)
            }
            .navigationTitle("Packets")
            .toolbar {
                #if JAILBREAK
                ToolbarItem(placement: .navigationBarTrailing) {
                    if appMode == .automatic {
                        PauseContinueButton(filter: $filter)
                    }
                }
                #endif
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingFilterView = true
                    } label: {
                        // Starting with iOS 15: line.3.horizontal.decrease.circle
                        Image(systemName: "line.horizontal.3.decrease.circle")
                    }
                }
            }
        }.onAppear {
            // Check for one time if the iPhone received ARI packets and if yes, automatically switch the filter to it
            if !filter.protoAutoSet {
                PersistenceController.shared.countPacketsByType { result in
                    do {
                        let (qmiPackets, ariPackets) = try result.get()
                        if qmiPackets == 0 && ariPackets == 0 {
                            Self.logger.debug("No packets recorded so far, deciding what to show at a later point")
                            return
                        }
                        if ariPackets > qmiPackets {
                            Self.logger.debug("Switch to ARI packets")
                            self.filter.proto = .ari
                        } else {
                            Self.logger.debug("Switch to QMI packets")
                            self.filter.proto = .qmi
                        }
                        self.filter.protoAutoSet = true
                    } catch {
                        Self.logger.warning("Couldn't count QMI & ARI packets: \(error)")
                    }
                }
            }
        }
        // Magic that prevents Pickers from closing
        // See: https://stackoverflow.com/a/70307271
        .navigationViewStyle(.stack)
    }
}

private struct PauseContinueButton: View {
    
    @Binding var filter: PacketFilterSettings
    
    var body: some View {
        Button {
            if filter.timeFrame == .live {
                if filter.pauseDate == nil {
                    filter.pauseDate = Date()
                } else {
                    filter.pauseDate = nil
                }
            } else {
                filter.timeFrame = .live
            }
        } label: {
            if filter.timeFrame == .live && filter.pauseDate == nil {
                Image(systemName: "pause")
            } else {
                Image(systemName: "play")
            }
        }
        // For now we disable the continue button for past traces as it lags when pressed
        .disabled(filter.timeFrame != .live)
    }
    
}

private struct FilteredPacketView: View {
    
    // We have to use separate fetch request as the preview crashes for a unified request
    @FetchRequest
    private var qmiPackets: FetchedResults<PacketQMI>
    
    @FetchRequest
    private var ariPackets: FetchedResults<PacketARI>
    
    private let filter: PacketFilterSettings
    
    init(filter: PacketFilterSettings) {
        self.filter = filter
        
        // https://www.hackingwithswift.com/quick-start/swiftui/how-to-limit-the-number-of-items-in-a-fetch-request
        let qmiRequest: NSFetchRequest<PacketQMI> = PacketQMI.fetchRequest()
        qmiRequest.fetchBatchSize = 25
        qmiRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PacketQMI.collected, ascending: false)]
        filter.applyTo(qmi: qmiRequest)
        
        let ariRequest: NSFetchRequest<PacketARI> = PacketARI.fetchRequest()
        ariRequest.fetchBatchSize = 25
        ariRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PacketARI.collected, ascending: false)]
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
    let qmiPackets: FetchedResults<PacketQMI>
    
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
    let ariPackets: FetchedResults<PacketARI>
    
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
