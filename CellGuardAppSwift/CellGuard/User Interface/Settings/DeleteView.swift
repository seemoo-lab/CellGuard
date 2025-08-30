//
//  DeleteView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 14.06.23.
//

import SwiftUI
import NavigationBackport

private enum DeleteAlert: Hashable, Identifiable {
    case deletionFailed(String)
    case exportWarning(Date?)

    var id: Self { return self }

    func alert(deleteFunc: @escaping () -> Void) -> Alert {
        switch self {
        case let .deletionFailed(reason):
            return Alert(
                title: Text("Deletion Failed"),
                message: Text("Failed to delete the selected datasets: \(reason)")
            )
        case let .exportWarning(lastExport):
            let formatter = RelativeDateTimeFormatter()

            let message: String
            if let lastExport = lastExport {
                message = "Your last exported data \(formatter.string(for: lastExport)!)"
            } else {
                message = "You never exported data"
            }

            return Alert(
                title: Text("No Export"),
                message: Text("\(message). You are about to delete data not exported!"),
                primaryButton: .cancel(),
                secondaryButton: .destructive(Text("Delete"), action: deleteFunc)
            )
        }
    }

}

struct DeleteView: View {

    public static let packetRetentionInfinite = 35.0
    public static let locationRetentionInfinite = 35.0

    // We fetch the entity counts in intervals as live updates cause too much lag
    @State private var cellMeasurements: Int = 0
    @State private var alsCells: Int = 0
    @State private var locations: Int = 0
    @State private var packets: Int = 0
    @State private var connectivityEvents: Int = 0
    @State private var sysdiagnoses: Int = 0

    // We fetch the database size in intervals as live updates wouldn't be possible
    @State private var databaseSize: UInt64 = 0

    @State private var doDeleteCells = true
    @State private var doDeleteALSCache = true
    @State private var doDeleteLocations = true
    @State private var doDeletePackets = true
    @State private var doDeleteConnectivityEvents = true
    @State private var doDeleteSysdiagnoses = true

    @State private var isDeletionInProgress = false
    @State private var deleteAlert: DeleteAlert?

    @AppStorage(UserDefaultsKeys.packetRetention.rawValue)
    private var packetRetentionDays: Double = 3
    @State private var deletingPackets: Bool = false

    @AppStorage(UserDefaultsKeys.locationRetention.rawValue)
    private var locationRetentionDays: Double = 7
    @State private var deletingLocations: Bool = false

    @State private var timer: Timer?

    @AppStorage(UserDefaultsKeys.lastExportDate.rawValue)
    private var lastExportDate: Double = -1

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
                Toggle(isOn: $doDeleteConnectivityEvents) {
                    Text("Connectivity Events (\(connectivityEvents))")
                        .transition(.opacity)
                        .id("DeleteView-ConnectivityEvents-\(connectivityEvents)")
                }
                Toggle(isOn: $doDeleteSysdiagnoses) {
                    Text("Sysdiagnoses (\(sysdiagnoses))")
                        .transition(.opacity)
                        .id("DeleteView-Sysdiagnoses-\(sysdiagnoses)")
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
                Slider(value: $packetRetentionDays, in: 1...Self.packetRetentionInfinite, step: 1)
            }

            Section(
                header: Text("Location Retention"),
                footer: Text(
                    locationRetentionDays >= Self.locationRetentionInfinite
                    ? "Keeping locations for an infinite amount of days"
                    : "Keeping locations for \(Int(locationRetentionDays)) \(Int(locationRetentionDays) != 1 ? "days" : "day"). Locations not assigned to cells are deleted automatically in the background.")
            ) {

                Slider(value: $locationRetentionDays, in: 1...Self.locationRetentionInfinite, step: 1)
            }

            Section(header: Text("Actions"), footer: Text(exportDateDescription())) {
                DeleteOldButton(text: "Delete Old Packets", active: $deletingPackets) {
                    PersistenceController.basedOnEnvironment().deletePacketsOlderThan(days: Int(packetRetentionDays))
                }
                DeleteOldButton(text: "Delete Old Locations", active: $deletingLocations) {
                    PersistenceController.basedOnEnvironment().deleteLocationsOlderThan(days: Int(locationRetentionDays))
                }
                Button {
                    if checkLastExport() {
                        delete()
                    }
                } label: {
                    HStack {
                        Text("Delete Selected Datasets")
                        Spacer()
                        if isDeletionInProgress {
                            ProgressView()
                        } else {
                            Image(systemName: "trash")
                        }
                    }
                }
                .disabled(!doDeleteCells && !doDeleteALSCache && !doDeleteLocations && !doDeletePackets && !doDeleteConnectivityEvents && !doDeleteSysdiagnoses)
            }
            .disabled(isDeletionInProgress)
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("Delete Data"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $deleteAlert, content: { alert in
            return alert.alert(deleteFunc: self.delete)
        })
        .onAppear {
            updateCounts(first: true)
            timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: { _ in
                // A bit hacky selfmade timer.
                // If we put the timer into the struct or into a onReceive method, it does not fire, but if we put it right here, it does work :)
                // See: https://stackoverflow.com/a/69128879
                // See: https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-a-timer-with-swiftui
                updateCounts(first: false)
            })

        }
        .onDisappear {
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

    func exportDateDescription() -> String {
        if lastExportDate < 0 {
            return "You never performed an export."
        }

        let date = Date(timeIntervalSince1970: lastExportDate)
        let formatter = RelativeDateTimeFormatter()

        return "You performed your last export \(formatter.string(for: date)!)."
    }

    func checkLastExport() -> Bool {
        if lastExportDate < 0 {
            deleteAlert = .exportWarning(nil)
            return false
        }

        let exportDate = Date(timeIntervalSince1970: lastExportDate)
        let twoHoursAgo = Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date.distantPast

        if exportDate <= twoHoursAgo {
            deleteAlert = .exportWarning(exportDate)
            return false
        }

        return true
    }

    func delete() {
        isDeletionInProgress = true

        let deletionCategories = [
            PersistenceCategory.connectedCells: doDeleteCells,
            PersistenceCategory.alsCells: doDeleteALSCache,
            PersistenceCategory.locations: doDeleteLocations,
            PersistenceCategory.packets: doDeletePackets,
            PersistenceCategory.connectivityEvents: doDeleteConnectivityEvents,
            PersistenceCategory.sysdiagnoses: doDeleteSysdiagnoses
        ].filter { $0.value }.map { $0.key }

        PersistenceController.basedOnEnvironment().deleteDataInBackground(categories: deletionCategories) { result in
            updateCounts(first: false)
            isDeletionInProgress = false
            do {
                // We don't have a deletion result, so we just check for an error
                try result.get()
            } catch {
                deleteAlert = .deletionFailed(error.localizedDescription)
            }
        }
    }

    func updateCounts(first: Bool) {
        DispatchQueue.global(qos: .utility).async {
            let persistence = PersistenceController.basedOnEnvironment()

            // Count entities of each database model
            let cellMeasurements = persistence.countEntitiesOf(CellTweak.fetchRequest()) ?? self.cellMeasurements
            let alsCells = persistence.countEntitiesOf(CellALS.fetchRequest()) ?? self.alsCells
            let locations = persistence.countEntitiesOf(LocationUser.fetchRequest()) ?? self.locations
            let packets = (persistence.countEntitiesOf(PacketQMI.fetchRequest()) ?? 0) + (persistence.countEntitiesOf(PacketARI.fetchRequest()) ?? 0)
            let connectivityEvents = persistence.countEntitiesOf(ConnectivityEvent.fetchRequest()) ?? self.connectivityEvents
            let sysdiagnoses = persistence.countEntitiesOf(Sysdiagnose.fetchRequest()) ?? self.sysdiagnoses

            // Calculate the size
            let size = PersistenceController.basedOnEnvironment().size()

            // Set the size on the main queue
            DispatchQueue.main.async {
                withAnimation(first ? .none : .easeIn) {
                    self.cellMeasurements = cellMeasurements
                    self.alsCells = alsCells
                    self.locations = locations
                    self.packets = packets
                    self.connectivityEvents = connectivityEvents
                    self.sysdiagnoses = sysdiagnoses
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
                } else {
                    Image(systemName: "delete.left")
                }
            }
        }
        .disabled(active)
    }

}

struct DeleteView_Previews: PreviewProvider {
    static var previews: some View {
        NBNavigationStack {
            DeleteView()
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
