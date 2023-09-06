//
//  DeleteView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 14.06.23.
//

import SwiftUI

struct DeleteView: View {
    
    public static let packetRetentionInfinite = 35.0
    public static let locationRetentionInfinite = 35.0
    
    // We fetch the entity counts in intervals as live updates cause too much lag
    @State private var cellMeasurements: Int = 0
    @State private var alsCells: Int = 0
    @State private var locations: Int = 0
    @State private var packets: Int = 0
    
    // We fetch the database size in intervals as live updates wouldn't be possible
    @State private var databaseSize: UInt64 = 0
    
    @State private var doDeleteCells = true
    @State private var doDeleteALSCache = true
    @State private var doDeleteLocations = true
    @State private var doDeletePackets = true
    
    @State private var isDeletionInProgress = false
    @State private var showFailAlert: Bool = false
    @State private var failReason: String? = nil
    
    @AppStorage(UserDefaultsKeys.packetRetention.rawValue)
    private var packetRetentionDays: Double = 3
    @State private var deletingPackets: Bool = false
    
    @AppStorage(UserDefaultsKeys.locationRetention.rawValue)
    private var locationRetentionDays: Double = 7
    @State private var deletingLocations: Bool = false
    
    @State private var timer: Timer? = nil
    
    var body: some View {
        List {
            Section(
                header: Text("Stored Datasets"),
                footer: Text("CellGuard's database uses \(formatBytes(databaseSize)) on disk.")
            ) {
                // The .id method is crucial for transitions
                // See: https://stackoverflow.com/a/60136737
                Toggle(isOn: $doDeleteCells) {
                    Text("Cell Measurements (\(cellMeasurements))")
                        .transition(.opacity)
                        .id("DeleteView-CellMeasurements-\(cellMeasurements)")
                }
                Toggle(isOn: $doDeleteALSCache) {
                    Text("ALS Cell Cache (\(alsCells))")
                        .transition(.opacity)
                        .id("DeleteView-ALSCellCache-\(alsCells)")
                }
                Toggle(isOn: $doDeleteLocations) {
                    Text("Locations (\(locations))")
                        .transition(.opacity)
                        .id("DeleteView-Locations-\(locations)")
                }
                Toggle(isOn: $doDeletePackets) {
                    Text("Packets (\(packets))")
                        .transition(.opacity)
                        .id("DeleteView-Packets-\(packets)")
                }
            }
            .disabled(isDeletionInProgress)
            
            Section(
                header: Text("Packet Retention"),
                footer: Text(
                    packetRetentionDays >= Self.packetRetentionInfinite
                    ? "Keeping packets for an infinite amount of days"
                    : "Keeping packets for \(Int(packetRetentionDays)) \(Int(packetRetentionDays) != 1 ? "days" : "day"). Packets not relevant for cell scoring are deleted automatically in the background.")
            ) {
                DeleteOldButton(text: "Delete old Packets", active: $deletingPackets) {
                    PersistenceController.basedOnEnvironment().deletePacketsOlderThan(days: Int(packetRetentionDays))
                }
                Slider(value: $packetRetentionDays, in: 1...Self.packetRetentionInfinite, step: 1)
            }
            
            Section(
                header: Text("Location Retention"),
                footer: Text(
                    locationRetentionDays >= Self.locationRetentionInfinite
                    ? "Keeping locations for an infinite amount of days"
                    : "Keeping locations for \(Int(locationRetentionDays)) \(Int(locationRetentionDays) != 1 ? "days" : "day"). Locations not assigned to cells are deleted automatically in the background.")
            ) {
                DeleteOldButton(text: "Delete old Locations", active: $deletingLocations) {
                    PersistenceController.basedOnEnvironment().deleteLocationsOlderThan(days: Int(locationRetentionDays))
                }
                Slider(value: $locationRetentionDays, in: 1...Self.locationRetentionInfinite, step: 1)
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
        .onAppear() {
            updateCounts(first: true)
            timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: { _ in
                // A bit hacky selfmade timer.
                // If we put the timer into the struct or into a onReceive method, it does not fire, but if we put it right here, it does work :)
                // See: https://stackoverflow.com/a/69128879
                // See: https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-a-timer-with-swiftui
                updateCounts(first: false)
            })
            
        }
        .onDisappear() {
            timer?.invalidate()
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
            updateCounts(first: false)
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
    
    func updateCounts(first: Bool) {
        DispatchQueue.global(qos: .utility).async {
            let persistence = PersistenceController.basedOnEnvironment()
            
            // Count entities of each database model
            let cellMeasurements = persistence.countEntitiesOf(TweakCell.fetchRequest()) ?? self.cellMeasurements
            let alsCells = persistence.countEntitiesOf(ALSCell.fetchRequest()) ?? self.alsCells
            let locations = persistence.countEntitiesOf(UserLocation.fetchRequest()) ?? self.locations
            let packets = (persistence.countEntitiesOf(QMIPacket.fetchRequest()) ?? 0) + (persistence.countEntitiesOf(ARIPacket.fetchRequest()) ?? 0)
            
            // Calculate the size
            let size = PersistenceController.shared.size()
            
            // Set the size on the main queue
            DispatchQueue.main.async {
                withAnimation(first ? .none : .easeIn) {
                    self.cellMeasurements = cellMeasurements
                    self.alsCells = alsCells
                    self.locations = locations
                    self.packets = packets
                    self.databaseSize = size
                }
            }
        }
    }
    
}

private struct DeleteOldButton: View {
    
    let text: String
    @Binding var active: Bool
    let deleteAction: () -> Void
    
    var body: some View {
        Button {
            active = true
            DispatchQueue.global(qos: .userInitiated).async {
                deleteAction()
                DispatchQueue.main.async {
                    active = false
                }
            }
        } label: {
            HStack {
                Text(text)
                Spacer()
                if active {
                    ProgressView()
                }
            }
        }
        .disabled(active)
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
