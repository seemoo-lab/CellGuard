//
//  ConnectivityDetailsView.swift
//  CellGuard
//
//  Created by mp on 11.07.25.
//

import CoreData
import SwiftUI

struct ConnectivityDetailsView: View {
    let group: GroupedConnectivityEvents

    var body: some View {
        if group.events.count == 1 {
            ConnectivityDetails(event: group.events.first!)
        } else {
            ConnectivityEventList(group: group)
        }
    }
}

private struct ConnectivityEventList: View {
    let group: GroupedConnectivityEvents

    var body: some View {
        let calendar = Calendar.current
        let sameDay = calendar.startOfDay(for: group.start) == calendar.startOfDay(for: group.end)

        List {
            ForEach(groupByDay(), id: \.key) { (day, dayEvents) in
                Section(header: Text(mediumDateFormatter.string(from: day))) {
                    ForEach(dayEvents) { event in
                        if let eventGroup = try? GroupedConnectivityEvents(events: [event], settings: group.settings) {
                            ConnectivityEventNavLink(group: eventGroup)
                        }
                    }
                }
            }
        }
        .navigationTitle(fullMediumDateTimeFormatter.string(from: group.start)
                         + " - "
                         + (sameDay ? mediumTimeFormatter : fullMediumDateTimeFormatter).string(from: group.end))
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
    }

    private func groupByDay() -> [(key: Date, value: [ConnectivityEvent])] {
        return Dictionary(grouping: group.events) { Calendar.current.startOfDay(for: $0.collected ?? Date()) }
            .sorted(by: {$0.key > $1.key})
    }
}

private struct ConnectivityEventNavLink: View {
    // We assume that the group contains just one event
    let group: GroupedConnectivityEvents

    var body: some View {
        NavigationLink {
            ConnectivityDetails(event: group.events.first!)
        } label: {
            ConnectivityEventListEntry(group: group)
        }
    }
}

private struct ConnectivityDetails: View {

    let event: ConnectivityEvent

    var body: some View {
        List {
            Group {
                Section(header: Text("Date & Time")) {
                    if let collectedDate = event.collected {
                        CellDetailsRow("Collected", fullMediumDateTimeFormatter.string(from: collectedDate))
                    }
                    if let importedDate = event.imported {
                        CellDetailsRow("Imported", fullMediumDateTimeFormatter.string(from: importedDate))
                    }
                }

                Section(header: Text("Connectivity Properties")) {
                    CellDetailsRow("Status", event.active ? "Connected" : "Disconnected")
                    CellDetailsRow("SIM Slot", Int(event.simSlot))
                    if event.basebandMode >= 0 {
                        CellDetailsRow("Baseband Mode", Int(event.basebandMode))
                    }
                    if event.registrationStatus >= 0 {
                        CellDetailsRow("Registration Status", Int(event.registrationStatus))
                    }

                    if let qmiPacket = event.packetQmi {
                        NavigationLink { PacketQMIDetailsView(packet: qmiPacket) } label: { PacketCell(packet: qmiPacket) }
                    } else if let ariPacket = event.packetAri {
                        NavigationLink { PacketARIDetailsView(packet: ariPacket) } label: { PacketCell(packet: ariPacket) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Connectivity Event")
    }

}
