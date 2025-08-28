//
//  PacketFilterSheet.swift
//  CellGuard
//
//  Created by Lukas Arnold on 13.06.23.
//

import OSLog
import CoreData
import SwiftUI
import NavigationBackport

class PacketFilterSettings: ObservableObject {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: PacketFilterSettings.self)
    )

    @Published var simSlotID: PacketFilterSimSlot = .all
    @Published var proto: PacketFilterProtocol = .qmi
    @Published var protoAutoSet: Bool = false
    @Published var direction: PacketFilterDirection = .all

    @Published var qmiType: PacketFilterQMIType = .all
    @Published var qmiServices: Set<UInt8> = Set(QMIDefinitions.shared.services.keys)

    @Published var ariGroups: Set<UInt8> = Set(ARIDefinitions.shared.groups.keys)

    @Published var timeFrame: PacketFilterTimeFrame = .live
    @Published var livePacketCount: Double = 200
    @Published var startDate = Date().addingTimeInterval(-60*30)
    @Published var endDate = Date()

    @Published var pauseDate: Date?
    @Published var pausedBeforeBackground = false

    func reset() {
        simSlotID = .all
        // We're not overwriting the settings proto & protoAutoSet
        direction = .all

        qmiType = .all
        qmiServices = Set(QMIDefinitions.shared.services.keys)

        ariGroups = Set(ARIDefinitions.shared.groups.keys)

        timeFrame = .live
        livePacketCount = 200
        startDate = Date().addingTimeInterval(-60*30)
        endDate = Date()

        pauseDate = nil
        pausedBeforeBackground = false
    }

    func determineProtoAutomatically() {
        if protoAutoSet {
            return
        }

        PersistenceController.basedOnEnvironment().countPacketsByType { result in
            // We're back in the MainActor
            do {
                let (qmiPackets, ariPackets) = try result.get()
                if qmiPackets == 0 && ariPackets == 0 {
                    Self.logger.debug("No packets recorded so far, deciding what to show at a later point")
                    return
                }
                if ariPackets > qmiPackets {
                    Self.logger.debug("Switch to ARI packets")
                    self.proto = .ari
                } else {
                    Self.logger.debug("Switch to QMI packets")
                    self.proto = .qmi
                }
                self.protoAutoSet = true
            } catch {
                Self.logger.warning("Couldn't count QMI & ARI packets: \(error)")
            }
        }
    }

    func enterForeground() {
        if !self.pausedBeforeBackground {
            self.pauseDate = nil
        }
    }

    func enterBackground() {
        self.pausedBeforeBackground = self.pauseDate != nil
        if !pausedBeforeBackground {
            self.pauseDate = Date()
        }
    }

    func applyTo(qmi request: NSFetchRequest<PacketQMI>) {
        if proto != .qmi {
            request.fetchLimit = 0
            return
        }

        var predicateList: [NSPredicate] = []

        if let slotNumber = simSlotID.slotNumber {
            predicateList.append(NSPredicate(format: "simSlotID == %@", NSNumber(value: slotNumber)))
        }

        if let direction = direction.cpt?.rawValue {
            predicateList.append(NSPredicate(format: "direction == %@", direction))
        }

        if let typeFilter = qmiType.db {
            // https://stackoverflow.com/a/34631602
            predicateList.append(NSPredicate(format: "indication == %@", NSNumber(value: typeFilter)))
        }

        if qmiServices.count < QMIDefinitions.shared.services.count {
            predicateList.append(NSCompoundPredicate(
                orPredicateWithSubpredicates: qmiServices.map { NSPredicate(format: "service == %@", NSNumber(value: $0)) }))
        }

        if timeFrame == .live {
            request.fetchLimit = Int(livePacketCount)
            if let pauseDate = pauseDate {
                predicateList.append(NSPredicate(format: "imported <= %@", pauseDate as NSDate))
            }
        } else {
            predicateList.append(NSPredicate(format: "collected >= %@", startDate as NSDate))
            predicateList.append(NSPredicate(format: "collected <= %@", endDate as NSDate))
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicateList)
    }

    func applyTo(ari request: NSFetchRequest<PacketARI>) {
        if proto != .ari {
            request.fetchLimit = 0
            return
        }

        var predicateList: [NSPredicate] = []

        if simSlotID != .all {
            predicateList.append(NSPredicate(format: "simSlotID == %@", NSNumber(value: simSlotID.rawValue)))
        }

        if let direction = direction.cpt?.rawValue {
            predicateList.append(NSPredicate(format: "direction == %@", direction))
        }

        if ariGroups.count < ARIDefinitions.shared.groups.count {
            predicateList.append(NSCompoundPredicate(
                orPredicateWithSubpredicates: ariGroups.map { NSPredicate(format: "group == %@", NSNumber(value: $0)) }))
        }

        if timeFrame == .live {
            request.fetchLimit = Int(livePacketCount)
            if let pauseDate = pauseDate {
                predicateList.append(NSPredicate(format: "imported <= %@", pauseDate as NSDate))
            }
        } else {
            predicateList.append(NSPredicate(format: "collected >= %@", startDate as NSDate))
            predicateList.append(NSPredicate(format: "collected <= %@", endDate as NSDate))
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicateList)
    }

}

enum PacketFilterSimSlot: UInt8, CaseIterable, Identifiable {
    case all, slot1, slot2, none

    var id: Self { self }

    var slotNumber: Int? {
        switch self {
        case .none:
            return 0
        case .slot1:
            return 1
        case .slot2:
            return 2
        default:
            return nil
        }
    }
}

enum PacketFilterProtocol: String, CaseIterable, Identifiable {
    case qmi, ari

    var id: Self { self }
}

enum PacketFilterDirection: String, CaseIterable, Identifiable {
    case all, ingoing, outgoing

    var id: Self { self }

    var cpt: CPTDirection? {
        switch self {
        case .all: return nil
        case .ingoing: return CPTDirection.ingoing
        case .outgoing: return CPTDirection.outgoing
        }
    }
}

enum PacketFilterQMIType: String, CaseIterable, Identifiable {
    case all, messages, indications

    var id: Self { self }

    var db: Bool? {
        switch self {
        case .all: return nil
        case .messages: return false
        case .indications: return true
        }
    }
}

enum PacketFilterTimeFrame: String, CaseIterable, Identifiable {
    case live, past

    var id: Self { self }
}

struct PacketFilterView: View {

    var body: some View {
        PacketFilterListView()
    }
}

struct PacketFilterListView: View {

    @EnvironmentObject var settings: PacketFilterSettings

    var body: some View {
        Form {
            Section(header: Text("Packets")) {
                Picker("Protocol", selection: $settings.proto) {
                    ForEach(PacketFilterProtocol.allCases) { Text($0.rawValue.uppercased()) }
                }
                Picker("Direction", selection: $settings.direction) {
                    ForEach(PacketFilterDirection.allCases) { Text($0.rawValue.capitalized) }
                }
                Picker("SIM Slot", selection: $settings.simSlotID) {
                    ForEach(PacketFilterSimSlot.allCases) { Text(String(describing: $0).capitalized) }
                }
                if settings.proto == .qmi {
                    Picker("Type", selection: $settings.qmiType) {
                        ForEach(PacketFilterQMIType.allCases) { Text($0.rawValue.capitalized) }
                    }
                    ListNavigationLink(value: PacketNavigationPath.filterServicesQmi) {
                        HStack {
                            Text("Services")
                            Spacer()
                            Text("\(settings.qmiServices.count)/\(allQmiServices.count)")
                                .foregroundColor(.gray)
                        }
                    }
                } else {
                    ListNavigationLink(value: PacketNavigationPath.filterGroupsAri) {
                        HStack {
                            Text("Groups")
                            Spacer()
                            Text("\(settings.ariGroups.count)/\(allAriGroups.count)")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            Section(header: Text("Data"), footer: Text(settings.timeFrame == .live ? "Showing the latest \(Int(settings.livePacketCount)) packets.": "")) {
                Picker("Display", selection: $settings.timeFrame) {
                    Text("Live").tag(PacketFilterTimeFrame.live)
                    Text("Recorded").tag(PacketFilterTimeFrame.past)
                }
                if settings.timeFrame == .live {
                    Toggle("Paused", isOn: Binding(get: {
                        settings.pauseDate != nil
                    }, set: { doPause in
                        if doPause {
                            settings.pauseDate = Date()
                        } else {
                            settings.pauseDate = nil
                        }
                    }))
                    HStack {
                        Image(systemName: "tray")
                            .foregroundColor(.gray)
                        Slider(value: $settings.livePacketCount, in: 50...1000, step: 10)
                        Image(systemName: "tray.2")
                            .foregroundColor(.gray)
                    }
                } else {
                    DatePicker("Start", selection: $settings.startDate, in: ...settings.endDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End", selection: $settings.endDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                }
            }
        }
        .navigationTitle("Filter")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem {
                Button {
                    settings.reset()
                } label: {
                    Text("Reset")
                }
            }
        }
    }
}

private let allQmiServices = QMIDefinitions.shared.services.values.sorted(by: {$0.id < $1.id})
struct PacketFilterQMIServicesView: View {

    @EnvironmentObject private var settings: PacketFilterSettings

    var body: some View {
        List(allQmiServices) { element in
            HStack {
                Text(element.name)
                Spacer()
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
                    .opacity(settings.qmiServices.contains(element.id) ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if settings.qmiServices.contains(element.id) {
                    settings.qmiServices.remove(element.id)
                } else {
                    settings.qmiServices.insert(element.id)
                }
            }
        }
        .navigationTitle("QMI Services")
        .toolbar {
            ToolbarItem {
                Button {
                    settings.qmiServices.formUnion(allQmiServices.map {$0.id})
                } label: {
                    Text("Reset")
                }
            }
        }
    }
}

private let allAriGroups = ARIDefinitions.shared.groups.values.sorted(by: {$0.id < $1.id})
struct PacketFilterARIGroupsView: View {

    @EnvironmentObject private var settings: PacketFilterSettings

    var body: some View {
        List(allAriGroups) { element in
            HStack {
                Text(element.name)
                Spacer()
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
                    .opacity(settings.ariGroups.contains(element.id) ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if settings.ariGroups.contains(element.id) {
                    settings.ariGroups.remove(element.id)
                } else {
                    settings.ariGroups.insert(element.id)
                }
            }
        }
        .navigationTitle("ARI Services")
        .toolbar {
            // Prevent the "< Filter" button from disappearing on iOS 14
            // See: https://stackoverflow.com/a/72432154
            ToolbarItem(placement: .navigationBarLeading) {
                Text("")
            }
            ToolbarItem {
                Button {
                    settings.ariGroups.formUnion(allAriGroups.map {$0.id})
                } label: {
                    Text("Reset")
                }
            }
        }
    }
}

struct PacketFilterView_Previews: PreviewProvider {
    static var previews: some View {
        @State var path = NBNavigationPath()
        @State var settings = PacketFilterSettings()

        NBNavigationStack(path: $path) {
            PacketFilterView()
                .environmentObject(settings)
        }
    }
}
