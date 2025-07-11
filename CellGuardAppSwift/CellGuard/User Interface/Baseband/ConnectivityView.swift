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

struct ConnectivityView: View {

    @State private var isShowingFilterView = false
    @State private var isShowingDateSheet = false
    @State var settings: ConnectivityListFilterSettings

    @State private var sheetDate = Date()
    @Environment(\.managedObjectContext) var managedObjectContext

    init(settings: ConnectivityListFilterSettings = ConnectivityListFilterSettings()) {
        self._settings = State(initialValue: settings)
    }

    var body: some View {
        VStack {
            // A workaround for that the NavigationLink on iOS does not respect the isShowingFilterView variable if it's embedded into a ToolbarItem.
            // See: https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-programmatic-navigation-in-swiftui
            // TODO: Upon pressing Apply the view sometimes forgets its origin (check view changes of the base NavigationView & this view)
            NavigationLink(isActive: $isShowingFilterView) {
                ConnectivityListFilterView(settingsBound: $settings) {
                    // Somehow this does not work on iOS 14 if a sub navigation has been opened by the filter settings
                    isShowingFilterView = false
                }
            } label: {
                EmptyView()
            }
            FilteredConnectivityView(settings: settings)
        }
        .navigationTitle("Connectivity")
        .toolbar {
            // We hide the toolbar buttons on iOS 14 if the view is shown with the past day settings,
            // because changing the date causes a the view to go rogue and forget its parent.
            ToolbarItem(placement: .navigationBarTrailing) {
                if #available(iOS 15, *) {
                    Button {
                        sheetDate = settings.date
                        isShowingDateSheet.toggle()
                    } label: {
                        Image(systemName: settings.timeFrame == .pastDays ? "calendar.badge.clock" : "calendar")
                    }
                } else {
                    if settings.timeFrame != .pastDays {
                        Button {
                            sheetDate = settings.date
                            isShowingDateSheet.toggle()
                        } label: {
                            Image(systemName: settings.timeFrame == .pastDays ? "calendar.badge.clock" : "calendar")
                        }
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if #available(iOS 15, *) {
                    Button {
                        isShowingFilterView = true
                    } label: {
                        // Starting with iOS 15: line.3.horizontal.decrease.circle
                        Image(systemName: "line.horizontal.3.decrease.circle")
                    }
                } else {
                    if settings.timeFrame != .pastDays {
                        Button {
                            isShowingFilterView = true
                        } label: {
                            // Starting with iOS 15: line.3.horizontal.decrease.circle
                            Image(systemName: "line.horizontal.3.decrease.circle")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingDateSheet) {
            SelectConnectivityDateView(
                settings: $settings,
                sheetDate: $sheetDate,
                isShowingDateSheet: $isShowingDateSheet
            )
            .environment(\.managedObjectContext, managedObjectContext)
        }
        // Magic that prevents Pickers from closing
        // See: https://stackoverflow.com/a/70307271
        .navigationViewStyle(.stack)
    }
}

private struct SelectConnectivityDateView: View {

    @Binding var settings: ConnectivityListFilterSettings
    @Binding var sheetDate: Date
    @Binding var isShowingDateSheet: Bool

    @FetchRequest
    private var first: FetchedResults<ConnectivityEvent>

    @FetchRequest
    private var last: FetchedResults<ConnectivityEvent>

    init(settings: Binding<ConnectivityListFilterSettings>, sheetDate: Binding<Date>, isShowingDateSheet: Binding<Bool>) {
        self._settings = settings
        self._sheetDate = sheetDate
        self._isShowingDateSheet = isShowingDateSheet

        let firstEventRequest: NSFetchRequest<ConnectivityEvent> = ConnectivityEvent.fetchRequest()
        firstEventRequest.fetchLimit = 1
        firstEventRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ConnectivityEvent.collected, ascending: true)]
        firstEventRequest.propertiesToFetch = ["collected"]
        self._first = FetchRequest(fetchRequest: firstEventRequest)

        let lastEventRequest: NSFetchRequest<ConnectivityEvent> = ConnectivityEvent.fetchRequest()
        lastEventRequest.fetchLimit = 1
        lastEventRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ConnectivityEvent.collected, ascending: false)]
        lastEventRequest.propertiesToFetch = ["collected"]
        self._last = FetchRequest(fetchRequest: lastEventRequest)
    }

    var dateRange: ClosedRange<Date> {
        let start = first.first?.collected ?? Date.distantPast
        let end = last.first?.collected ?? Date()
        return start...end
    }

    var body: some View {
        VStack {
            Text("Select Date")
                .font(.headline)
            Text("Choose a date to inspect connectivity events")
                .font(.subheadline)
                .padding([.bottom], 40)

            DatePicker("Event Date", selection: $sheetDate, in: dateRange, displayedComponents: [.date])
                .datePickerStyle(.graphical)

            Button {
                let selectedDate: Date
                if let lastDate = last.first?.collected {
                    selectedDate = sheetDate > lastDate ? lastDate : sheetDate
                } else {
                    selectedDate = sheetDate
                }

                let startOfToday = Calendar.current.startOfDay(for: Date())
                let startOfDate: Date = Calendar.current.startOfDay(for: selectedDate)

                settings.timeFrame = startOfToday == startOfDate ? .live : .pastDay
                settings.date = selectedDate
                isShowingDateSheet.toggle()
            } label: {
                Text("Apply")
                    .bold()
            }
            .padding([.top], 40)
        }
        .padding()
    }

}

private struct FilteredConnectivityView: View {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: FilteredConnectivityView.self)
    )

    private let settings: ConnectivityListFilterSettings

    @FetchRequest
    private var events: FetchedResults<ConnectivityEvent>

    init(settings: ConnectivityListFilterSettings) {
        self.settings = settings

        let eventsRequest: NSFetchRequest<ConnectivityEvent> = ConnectivityEvent.fetchRequest()
        // cellsRequest.fetchBatchSize = 25
        eventsRequest.sortDescriptors = [NSSortDescriptor(key: "collected", ascending: false)]
        settings.applyTo(request: eventsRequest)

        self._events = FetchRequest(fetchRequest: eventsRequest, animation: .easeOut)
    }

    private func groupEvents() -> [GroupedConnectivityEvents] {
        var groups: [GroupedConnectivityEvents] = []

        // Iterate through all measurements and start a new group upon encountering a new cell
        var groupEvents: [ConnectivityEvent] = []
        for event in events {
            if let lastEvent = groupEvents.last, settings.active != nil || lastEvent.active != event.active {
                do {
                    groups.append(try GroupedConnectivityEvents(events: groupEvents, settings: settings))
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
                groups.append(try GroupedConnectivityEvents(events: groupEvents, settings: settings))
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
                GroupedNavigationLink(group: eventGroup)
            }
            .listStyle(.insetGrouped)
        } else {
            Text("No connectivity events match your query.")
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}

private struct GroupedNavigationLink: View {

    let group: GroupedConnectivityEvents

    var body: some View {
        return NavigationLink {
            ConnectivityDetailsView(group: group)
        } label: {
            ConnectivityEventListEntry(group: group)
        }
    }

}

struct ConnectivityEventListEntry: View {

    private let group: GroupedConnectivityEvents
    private var simSlots = Set<Int16>()

    init(group: GroupedConnectivityEvents) {
        self.group = group

        for event in group.events {
            simSlots.insert(event.simSlot)
        }
    }

    var body: some View {
        let calendar = Calendar.current
        let sameDay = calendar.startOfDay(for: group.start) == calendar.startOfDay(for: group.end)

        VStack {
            HStack {
                Text(group.events.first!.active ? "Connected" : "Disconnected")
                    .bold()
                if !simSlots.isEmpty && simSlots != [0] {
                    HStack(spacing: 2) {
                        Image(systemName: "simcard")
                            .font(.system(size: 12))
                        Text(simSlots.map { "\($0)" }.sorted().joined(separator: ","))
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.gray)
                }

                Spacer()
            }
            HStack {
                if group.events.count == 1 {
                    Text(fullMediumDateTimeFormatter.string(from: group.start))
                } else {
                    Text(fullMediumDateTimeFormatter.string(from: group.start))
                    + Text(" - ")
                    + Text((sameDay ? mediumTimeFormatter : fullMediumDateTimeFormatter).string(from: group.end))
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
        NavigationView {
            ConnectivityView()
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
