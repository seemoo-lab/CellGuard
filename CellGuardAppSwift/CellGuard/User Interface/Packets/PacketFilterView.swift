//
//  PacketFilterSheet.swift
//  CellGuard
//
//  Created by Lukas Arnold on 13.06.23.
//

import CoreData
import SwiftUI

struct PacketFilterSettings {
    var proto: PacketFilterProtocol = .qmi
    var protoAutoSet: Bool = false
    var direction: PacketFilterDirection = .all
    
    var qmiType: PacketFilterQMIType = .all
    var qmiServices: Set<UInt8> = Set(QMIDefinitions.shared.services.keys)
    
    var ariGroups: Set<UInt8> = Set(ARIDefinitions.shared.groups.keys)
    
    var timeFrame: PacketFilterTimeFrame = .live
    var livePacketCount: Double = 200
    var startDate = Date().addingTimeInterval(-60*30)
    var endDate = Date()
    
    var pauseDate: Date? = nil
    
    func applyTo(qmi request: NSFetchRequest<PacketQMI>) {
        if proto != .qmi {
            request.fetchLimit = 0
            return
        }
        
        var predicateList: [NSPredicate] = []
        
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

enum PacketFilterProtocol: String, CaseIterable, Identifiable {
    case qmi, ari
    
    var id: Self { self }
}

enum PacketFilterDirection: String, CaseIterable, Identifiable {
    case all, ingoing, outgoing
    
    var id: Self { self }
    
    var cpt: CPTDirection? {
        switch (self) {
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
        switch (self) {
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
    
    let close: () -> Void
    
    @Binding var settingsBound: PacketFilterSettings
    @State var settings: PacketFilterSettings = PacketFilterSettings()
    
    init(settingsBound: Binding<PacketFilterSettings>, close: @escaping () -> Void) {
        self.close = close
        self._settingsBound = settingsBound
        self._settings = State(wrappedValue: self._settingsBound.wrappedValue)
    }
    
    var body: some View {
        PacketFilterListView(settings: $settings)
        .navigationTitle("Filter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    self.settingsBound = settings
                    self.close()
                } label: {
                    Text("Apply")
                }
            }
        }
        .listStyle(.insetGrouped)
        // There's an evil bug in iOS 15.2, where onAppear is called multiple times
        // See: https://developer.apple.com/forums/thread/666345
        // Therefore we rely on the constructor and hope that is called every time
        /*.onAppear() {
            print("On Appear (changed)")
            self.settings = settingsBound
        } */
    }
}

private struct PacketFilterListView: View {
    
    @Binding var settings: PacketFilterSettings
    
    var body: some View {
        Form {
            Section(header: Text("Packets")) {
                Picker("Protocol", selection: $settings.proto) {
                    ForEach(PacketFilterProtocol.allCases) { Text($0.rawValue.uppercased()) }
                }
                Picker("Direction", selection: $settings.direction) {
                    ForEach(PacketFilterDirection.allCases) { Text($0.rawValue.capitalized) }
                }
                if settings.proto == .qmi {
                    Picker("Type", selection: $settings.qmiType) {
                        ForEach(PacketFilterQMIType.allCases) { Text($0.rawValue.capitalized) }
                    }
                    NavigationLink {
                        PacketFilterQMIServicesView(
                            all: QMIDefinitions.shared.services.values.sorted(by: {$0.id < $1.id}),
                            selected: $settings.qmiServices
                        )
                    } label: {
                        Text("Services")
                    }
                } else {
                    NavigationLink {
                        PacketFilterARIGroupsView(
                            all: ARIDefinitions.shared.groups.values.sorted(by: {$0.id < $1.id}),
                            selected: $settings.ariGroups
                        )
                    } label: {
                        Text("Groups")
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
        // The Picker Style menu is broken on iOS 14 & 15 if Pickers are in Sections.
        // Therefore we use the default fallback to the navigation picker even if it looks not so nice and comes with its own set of bugs ):
    }
}

private struct PacketFilterQMIServicesView: View {
    
    let all: [QMIDefinitionService]
    @Binding var selected: Set<UInt8>
    
    var body: some View {
        List(all) { element in
            HStack {
                Text(element.name)
                Spacer()
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
                    .opacity(selected.contains(element.id) ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if selected.contains(element.id) {
                    selected.remove(element.id)
                } else {
                    selected.insert(element.id)
                }
            }
        }
        .navigationTitle("QMI Services")
        .toolbar {
            // Prevent the "< Filter" button from disappearing on iOS 14
            // See: https://stackoverflow.com/a/72432154
            ToolbarItem(placement: .navigationBarLeading) {
                Text("")
            }
            ToolbarItem {
                Button {
                    selected.formUnion(all.map {$0.id})
                } label: {
                    Text("Reset")
                }
            }
        }
    }
}

private struct PacketFilterARIGroupsView: View {
    
    let all: [ARIDefinitionGroup]
    @Binding var selected: Set<UInt8>
    
    var body: some View {
        List(all) { element in
            HStack {
                Text(element.name)
                Spacer()
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
                    .opacity(selected.contains(element.id) ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if selected.contains(element.id) {
                    selected.remove(element.id)
                } else {
                    selected.insert(element.id)
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
                    selected.formUnion(all.map {$0.id})
                } label: {
                    Text("Reset")
                }
            }
        }
    }
}

struct PacketFilterView_Previews: PreviewProvider {
    static var previews: some View {
        @State var settings = PacketFilterSettings()
        
        NavigationView {
            PacketFilterView(settingsBound: $settings) {
                // Doing nothing
            }
        }
    }
}
