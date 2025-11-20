//
//  PacketTabView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 08.06.23.
//

import CoreData
import SwiftUI
import OSLog
import Combine
import NavigationBackport

struct PacketTabView: View {

    @AppStorage(UserDefaultsKeys.appMode.rawValue) private var appMode: DataCollectionMode = .none

    @State private var path = NBNavigationPath()
    @StateObject private var filter: PacketFilterSettings = PacketFilterSettings()
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
                        Image(systemName: CGIcons.filter)
                    }
                }
            }
            .nbNavigationDestination(for: PacketNavigationPath.self) { nav in
                PacketNavigationPath.navigate(nav)
            }
            .cgNavigationDestinations(.packets)
            .cgNavigationDestinations(.sysdiagnoses)
            .cgNavigationDestinations(.picker)
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

class FetchUpdater<T: NSManagedObject>: ObservableObject {
    @Published var currentResults: [T] = []
    private var timerCancellable: AnyCancellable?
    private var makeFetchRequest: () -> NSFetchRequest<T>

    init(makeFetchRequest: @escaping () -> NSFetchRequest<T>, updateInterval: TimeInterval = 5) {
        self.makeFetchRequest = makeFetchRequest
        updateResults()

        timerCancellable = Timer
            .publish(every: updateInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateResults() }
    }

    private func updateResults() {
        let fetchRequest = self.makeFetchRequest()
        if let results = try? PersistenceController.shared.container.viewContext.fetch(fetchRequest) {
            withAnimation {
                self.currentResults = results
            }
        }
    }
}

private struct FilteredPacketView: View {

    // We have to use separate fetch request as the preview crashes for a unified request
    @ObservedObject private var qmiPacketsUpdater: FetchUpdater<PacketQMI>
    @ObservedObject private var ariPacketsUpdater: FetchUpdater<PacketARI>
    private let filter: PacketFilterSettings

    init(filter: PacketFilterSettings) {
        self.filter = filter

        self.qmiPacketsUpdater = FetchUpdater(makeFetchRequest: {
            let qmiRequest: NSFetchRequest<PacketQMI> = PacketQMI.fetchRequest()
            qmiRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PacketQMI.collected, ascending: false)]
            filter.applyTo(qmi: qmiRequest)
            return qmiRequest
        })
        self.ariPacketsUpdater = FetchUpdater(makeFetchRequest: {
            let ariRequest: NSFetchRequest<PacketARI> = PacketARI.fetchRequest()
            ariRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PacketARI.collected, ascending: false)]
            filter.applyTo(ari: ariRequest)
            return ariRequest
        })
    }

    var body: some View {
        if filter.proto == .qmi {
            if qmiPacketsUpdater.currentResults.isEmpty {
                Text("No packets match your search criteria.")
            } else {
                PacketList(packets: qmiPacketsUpdater.currentResults)
            }
        } else {
            if ariPacketsUpdater.currentResults.isEmpty {
                Text("No packets match your search criteria.")
            } else {
                PacketList(packets: ariPacketsUpdater.currentResults)
            }
        }
    }
}

private struct PacketList<T: NSManagedObject & Packet>: View {
    let packets: [T]

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
