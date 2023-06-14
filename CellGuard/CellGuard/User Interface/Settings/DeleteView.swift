//
//  DeleteView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 14.06.23.
//

import SwiftUI

struct DeleteView: View {
    @FetchRequest(sortDescriptors: [])
    private var connectedCellCount: FetchedResults<TweakCell>
    @FetchRequest(sortDescriptors: [])
    private var alsCellCount: FetchedResults<ALSCell>
    @FetchRequest(sortDescriptors: [])
    private var locationCount: FetchedResults<UserLocation>
    @FetchRequest(sortDescriptors: [])
    private var packetQMICount: FetchedResults<QMIPacket>
    @FetchRequest(sortDescriptors: [])
    private var packetARICount: FetchedResults<ARIPacket>
    
    @State private var databaseSize: UInt64 = 0
    
    @State private var doDeleteCells = true
    @State private var doDeleteALSCache = true
    @State private var doDeleteLocations = true
    @State private var doDeletePackets = true
    
    @State private var isDeletionInProgress = false
    @State private var showFailAlert: Bool = false
    @State private var failReason: String? = nil
    
    @AppStorage(UserDefaultsKeys.packetRetention.rawValue)
    private var packetRetentionDays: Double = 14
    
    var body: some View {
        List {
            Section(
                header: Text("Stored Datasets"),
                footer: Text("CellGuard's database uses \(formatBytes(databaseSize)) on disk.")
            ) {
                Toggle("Connected Cells (\(connectedCellCount.count))", isOn: $doDeleteCells)
                Toggle("Cell Cache (\(alsCellCount.count))", isOn: $doDeleteALSCache)
                Toggle("Locations (\(locationCount.count))", isOn: $doDeleteLocations)
                Toggle("Packets (\(packetQMICount.count + packetARICount.count))", isOn: $doDeletePackets)
            }
            .disabled(isDeletionInProgress)
            
            Section(
                header: Text("Packet Retention"),
                footer: Text("Keeping packets for \(Int(packetRetentionDays)) \(Int(packetRetentionDays) != 1 ? "days" : "day").")
            ) {
                Slider(value: $packetRetentionDays, in: 1...35, step: 1)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("Data"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Prevent the "< Settings" button from disappearing on iOS 14
            // See: https://stackoverflow.com/a/72432154
            ToolbarItem(placement: .navigationBarLeading) {
                Text("")
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if (isDeletionInProgress) {
                    ProgressView()
                }
            }
            
            ToolbarItem(placement: .destructiveAction) {
                Button {
                    delete()
                } label: {
                    Text("Delete")
                        .foregroundColor(.red)
                }
                .disabled(!doDeleteCells && !doDeleteALSCache && !doDeleteLocations && !doDeletePackets || isDeletionInProgress)
            }
        }
        .alert(isPresented: $showFailAlert) {
            Alert(
                title: Text("Deletion Failed"),
                message: Text("Failed to delete the selected datasets: \(failReason ?? "Unknown")")
            )
        }
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { input in
            // Again, a bit hacky. If we put the timer into the struct, it does not fire, but if we put it right here, it does work :)
            // See: https://stackoverflow.com/a/69128879
            // See: https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-a-timer-with-swiftui
            updateDatabaseSize()
        }
        .onAppear() {
            updateDatabaseSize()
        }
    }
    
    func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.allowsNonnumericFormatting = false
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    func delete() {
        isDeletionInProgress = true
        
        let deletionCategories = [
            PersistenceCategory.connectedCells: doDeleteCells,
            PersistenceCategory.alsCells: doDeleteALSCache,
            PersistenceCategory.locations: doDeleteLocations,
            PersistenceCategory.packets: doDeletePackets,
        ].filter { $0.value }.map { $0.key }
        
        PersistenceController.shared.deleteDataInBackground(categories: deletionCategories) { result in
            updateDatabaseSize()
            isDeletionInProgress = false
            do {
                // We don't have a deletion result, so we just check for an error
                try result.get()
            } catch {
                failReason = error.localizedDescription
                showFailAlert = true
            }
        }
    }
    
    func updateDatabaseSize() {
        DispatchQueue.global(qos: .userInitiated).async {
            // Calculate the size
            let size = PersistenceController.shared.size()
            
            // Set the size on the main queue
            DispatchQueue.main.async {
                self.databaseSize = size
            }
        }
    }
    
}

struct DeleteView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DeleteView()
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
