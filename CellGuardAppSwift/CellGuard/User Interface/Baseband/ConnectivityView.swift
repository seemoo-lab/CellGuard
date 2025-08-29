//
//  CellListView.swift
//  CellGuard
//
//  Created by mp on 04.07.25.
//

import CoreData
import Foundation
import SwiftUI
import OSLog
import NavigationBackport

struct ConnectivityView: View {

    @State private var isShowingDateSheet = false
    @State private var sheetRange = Date.distantPast...Date.distantFuture

    @EnvironmentObject private var navigator: PathNavigator
    @EnvironmentObject private var settings: ConnectivityFilterSettings

    var body: some View {
        FilteredConnectivityView(settings: settings)
        .navigationTitle("Connectivity")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isShowingDateSheet = true
                } label: {
                    Image(systemName: settings.timeFrame == .pastDays ? "calendar.badge.clock" : "calendar")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    navigator.push(SummaryNavigationPath.connectivityFilter)
                } label: {
                    // Starting with iOS 15: line.3.horizontal.decrease.circle
                    Image(systemName: "line.horizontal.3.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $isShowingDateSheet) {
            SelectDateSheet(timeFrame: $settings.timeFrame, date: $settings.date, sheetRange: $sheetRange)
        }
        .onAppear {
            Task.detached {
                if let range = await PersistenceController.basedOnEnvironment().fetchConnectivityDateRange() {
                    await MainActor.run {
                        sheetRange = range
                    }
                }
            }
        }
    }
}

private struct FilteredConnectivityView: View {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: FilteredConnectivityView.self)
    )

    private let settings: ConnectivityFilterSettings

    @FetchRequest
    private var events: FetchedResults<ConnectivityEvent>

    init(settings: ConnectivityFilterSettings) {
        self.settings = settings

        let eventsRequest: NSFetchRequest<ConnectivityEvent> = ConnectivityEvent.fetchRequest()
        // cellsRequest.fetchBatchSize = 25
        eventsRequest.sortDescriptors = [NSSortDescriptor(key: "collected", ascending: false)]
        settings.applyTo(request: eventsRequest)

        self._events = FetchRequest(fetchRequest: eventsRequest, animation: .easeOut)
    }

    private func groupEvents() -> [GroupedConnectivityEvents] {
        var groups: [GroupedConnectivityEvents] = []

        // Iterate through all measurements and start a new group upon encountering a new event
        var groupEvents: [ConnectivityEvent] = []
        for event in events {
            if let lastEvent = groupEvents.last, settings.active != nil || lastEvent.active != event.active {
                do {
                    groups.append(try GroupedConnectivityEvents(events: groupEvents))
                } catch {
                    Self.logger.warning("Can't group connectivity events (\(groupEvents)): \(error)")
                }
                groupEvents = []
            }

            groupEvents.append(event)
        }

        // The final batch of measurements
        if !groupEvents.isEmpty {
            do {
                groups.append(try GroupedConnectivityEvents(events: groupEvents))
            } catch {
                Self.logger.warning("Can't group connectivity events (\(groupEvents)): \(error)")
            }
        }

        return groups
    }

    var body: some View {
        let groupedEvents = groupEvents()
        if !groupedEvents.isEmpty {
            List(groupedEvents) { eventGroup in
                ListNavigationLink(value: NavListIds(objects: eventGroup.events)) {
                    ConnectivityEventListEntry(group: eventGroup)
                }
            }
            .listStyle(.insetGrouped)
        } else {
            Text("No connectivity events match your query.")
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}

struct ConnectivityEventListEntry: View {

    private let events: [ConnectivityEvent]
    private let startDate: Date
    private let endDate: Date
    private let simSlots: Set<Int16>

    init(group: GroupedConnectivityEvents) {
        self.events = group.events
        self.startDate = group.start
        self.endDate = group.end
        self.simSlots = Set(group.events.map { $0.simSlot })
    }

    init(event: ConnectivityEvent) {
        self.events = [event]
        self.startDate = event.collected ?? Date.distantPast
        self.endDate = event.collected ?? Date.distantFuture
        self.simSlots = Set([event.simSlot])
    }

    var body: some View {
        let calendar = Calendar.current
        let sameDay = calendar.startOfDay(for: startDate) == calendar.startOfDay(for: endDate)

        VStack {
            HStack {
                Text(events.first!.active ? "Connected" : "Disconnected")
                    .bold()
                if !simSlots.isEmpty && simSlots != [0] {
                    HStack(spacing: 2) {
                        Image(systemName: "simcard")
                            .font(.system(size: 12))
                        Text(simSlots.map { $0 == 0 ? "None" : "\($0)" }.sorted().joined(separator: ","))
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.gray)
                }

                Spacer()
            }
            HStack {
                if events.count == 1 {
                    Text(fullMediumDateTimeFormatter.string(from: startDate))
                } else {
                    Text(fullMediumDateTimeFormatter.string(from: endDate))
                    + Text(" - ")
                    + Text((sameDay ? mediumTimeFormatter : fullMediumDateTimeFormatter).string(from: endDate))
                }
                Spacer()
            }
            .font(.system(size: 14))
            .foregroundColor(.gray)
        }
    }
}

struct ConnectivityView_Previews: PreviewProvider {
    static var previews: some View {
        @State var connectivityFilterSettings = ConnectivityFilterSettings()

        NBNavigationStack {
            ConnectivityView()
                .cgNavigationDestinations(.connectivity)
                .cgNavigationDestinations(.packets)
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(connectivityFilterSettings)
    }
}
