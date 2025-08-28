//
//  PacketTabView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 08.06.23.
//

import CoreData
import SwiftUI
import OSLog
import NavigationBackport

struct PacketTabView: View {

    @AppStorage(UserDefaultsKeys.appMode.rawValue) private var appMode: DataCollectionMode = .none

    @State private var path = NBNavigationPath()
    @State private var filter: PacketFilterSettings = PacketFilterSettings()
    @State private var backgroundObserver: NSObjectProtocol?
    @State private var foregroundObserver: NSObjectProtocol?

    var body: some View {
        NBNavigationStack(path: $path) {
            FilteredPacketView(filter: filter)
            .navigationTitle("Packets")
            .toolbar {
                #if JAILBREAK
                ToolbarItem(placement: .navigationBarTrailing) {
                    if appMode == .automatic {
                        PauseContinueButton()
                    }
                }
                #endif
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        path.push(PacketNavigationPath.filter)
                    } label: {
                        // Starting with iOS 15: line.3.horizontal.decrease.circle
                        Image(systemName: "line.horizontal.3.decrease.circle")
                    }
                }
            }
            .nbNavigationDestination(for: PacketNavigationPath.self) { nav in
                PacketNavigationPath.navigate(nav)
            }
            .nbNavigationDestination(for: NavObjectId<PacketARI>.self) { id in
                id.ensure { PacketARIDetailsView(packet: $0) }
            }
            .nbNavigationDestination(for: NavObjectId<PacketQMI>.self) { id in
                id.ensure { PacketQMIDetailsView(packet: $0) }
            }
        }.onAppear {
            // Check for one time if the iPhone received ARI packets and if yes, automatically switch the filter to it
            filter.determineProtoAutomatically()

            #if JAILBREAK
            // Pause the FilteredPacketView when entering background.
            self.backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
                filter.enterBackground()
            }
            self.foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
                filter.enterForeground()
            }
            #endif
        }
        .onDisappear {
            #if JAILBREAK
            if let backgroundObserver = self.backgroundObserver {
                NotificationCenter.default.removeObserver(backgroundObserver)
            }
            if let foregroundObserver = self.foregroundObserver {
                NotificationCenter.default.removeObserver(foregroundObserver)
            }
            #endif
        }
        .environmentObject(filter)
    }
}

private struct PauseContinueButton: View {

    @EnvironmentObject var filter: PacketFilterSettings

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
    @FetchRequest private var qmiPackets: FetchedResults<PacketQMI>
    @FetchRequest private var ariPackets: FetchedResults<PacketARI>
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
                PacketList(packets: qmiPackets)
            }
        } else {
            if ariPackets.isEmpty {
                Text("No packets match your search criteria.")
            } else {
                PacketList(packets: ariPackets)
            }
        }
    }
}

private struct PacketList<T: NSManagedObject & Packet>: View {
    let packets: FetchedResults<T>

    var body: some View {
        List(packets) { packet in
            ListNavigationLink(value: NavObjectId(object: packet)) {
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
