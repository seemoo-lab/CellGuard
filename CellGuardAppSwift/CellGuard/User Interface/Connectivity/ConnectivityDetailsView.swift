//
//  ConnectivityDetailsView.swift
//  CellGuard
//
//  Created by mp on 11.07.25.
//

import CoreData
import SwiftUI
import NavigationBackport

struct ConnectivityEventList: View {
    private let eventsByDay: [(key: Date, value: [ConnectivityEvent])]
    private let groupStart: Date
    private let groupEnd: Date
    private let sameDay: Bool

    init(events: [ConnectivityEvent]) {
        let timestamps = events.compactMap { $0.collected }

        self.groupStart = timestamps.min() ?? Date.distantPast
        self.groupEnd = timestamps.max() ?? Date.distantFuture

        let calendar = Calendar.current
        self.sameDay = calendar.startOfDay(for: self.groupStart) == calendar.startOfDay(for: self.groupEnd)

        self.eventsByDay = Dictionary(grouping: events) {
            calendar.startOfDay(for: $0.collected ?? Date())
        }.sorted(by: {$0.key > $1.key})
    }

    var body: some View {
        List {
            ForEach(eventsByDay, id: \.key) { (day, dayEvents) in
                Section(header: Text(mediumDateFormatter.string(from: day))) {
                    ForEach(dayEvents) { event in
                        ListNavigationLink(value: NavObjectId(object: event)) {
                            ConnectivityEventListEntry(event: event)
                        }
                    }
                }
            }
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
    }

    var navTitle: String {
        fullMediumDateTimeFormatter.string(from: groupStart)
        + " - "
        + (sameDay ? mediumTimeFormatter : fullMediumDateTimeFormatter).string(from: groupEnd)
    }
}

struct ConnectivityEventDetails: View {
    let event: ConnectivityEvent

    var body: some View {
        List {
            Section(header: Text("Date & Time")) {
                if let collectedDate = event.collected {
                    DetailsRow("Collected", fullMediumDateTimeFormatter.string(from: collectedDate))
                }
                if let importedDate = event.imported {
                    DetailsRow("Imported", fullMediumDateTimeFormatter.string(from: importedDate))
                }
            }

            Section(header: Text("Connectivity Properties")) {
                DetailsRow("Status", event.active ? "Connected" : "Disconnected")
                DetailsRow("SIM Slot", event.simSlot == 0 ? "None" : String(event.simSlot))
                if event.basebandMode >= 0 {
                    DetailsRow("Baseband Mode", Int(event.basebandMode))
                }
                if event.registrationStatus >= 0 {
                    DetailsRow("Registration Status", Int(event.registrationStatus))
                }
                if event.simUnlocked != nil {
                    DetailsRow("SIM Unlocked", bool: event.simUnlocked!)
                }

                if let qmiPacket = event.packetQmi {
                    ListNavigationLink(value: NavObjectId<PacketQMI>(object: qmiPacket)) {
                        PacketCell(packet: qmiPacket)
                    }
                } else if let packetAri = event.packetAri {
                    ListNavigationLink(value: NavObjectId<PacketARI>(object: packetAri)) {
                        PacketCell(packet: packetAri)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(event.title)
    }

}
