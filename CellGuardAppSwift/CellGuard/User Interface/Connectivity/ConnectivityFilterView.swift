//
//  CellListFilterView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.07.23.
//

import CoreData
import SwiftUI
import NavigationBackport

class ConnectivityFilterSettings: ObservableObject {
    @Published var date: Date = Calendar.current.startOfDay(for: Date())
    @Published var timeFrame: FilterTimeFrame = .live
    @Published var simSlot: FilterSimSlot = .all
    @Published var active: Bool?

    func reset() {
        date = Calendar.current.startOfDay(for: Date())
        timeFrame = .live
        simSlot = .all
        active = nil
    }

    func showLatestData(range: ClosedRange<Date>) {
        if timeFrame == .live && !range.contains(date) {
            date = range.upperBound
            timeFrame = .pastDay
        }
    }

    func predicates(startDate: Date?, endDate: Date?) -> [NSPredicate] {
        var predicateList: [NSPredicate] = []

        if let start = startDate {
            predicateList.append(NSPredicate(format: "%@ <= collected", start as NSDate))
        }
        if let end = endDate {
            predicateList.append(NSPredicate(format: "collected <= %@", end as NSDate))
        }

        if let slotNumber = simSlot.slotNumber {
            predicateList.append(NSPredicate(format: "simSlot == %@", NSNumber(value: slotNumber)))
        }

        if let active = active {
            predicateList.append(NSPredicate(format: "active == %@", NSNumber(value: active)))
        }

        return predicateList
    }

    func applyTo(request: NSFetchRequest<ConnectivityEvent>) {
        var beginDate: Date
        var endDate: Date
        let calendar = Calendar.current

        switch timeFrame {
        case .live:
            beginDate = calendar.startOfDay(for: Date())
            endDate = calendar.date(byAdding: .day, value: 1, to: beginDate)!
        case .pastDay:
            beginDate = calendar.startOfDay(for: date)
            endDate = calendar.date(byAdding: .day, value: 1, to: beginDate)!
        case .pastDays:
            beginDate = calendar.startOfDay(for: date)
            endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates(startDate: beginDate, endDate: endDate))
    }

}

struct ConnectivityListFilterView: View {

    var body: some View {
        ConnectivityListFilterSettingsView()
        .navigationTitle("Filter")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ConnectivityListFilterSettingsView: View {

    @EnvironmentObject var settings: ConnectivityFilterSettings

    var body: some View {
        Form {
            Section(header: Text("Connectivity Events")) {
                // See: https://stackoverflow.com/a/59348094
                Picker("Connection", selection: $settings.active) {
                    Text("All").tag(nil as Bool?)
                    Text("Connected").tag(true)
                    Text("Disconnected").tag(false)
                }
                Picker("SIM Slot", selection: $settings.simSlot) {
                    ForEach(FilterSimSlot.allCases) { Text(String(describing: $0).capitalized) }
                }
            }
        }
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

struct ConnectivityListFilterView_Previews: PreviewProvider {
    static var previews: some View {
        @State var settings = ConnectivityFilterSettings()

        NBNavigationStack {
            ConnectivityListFilterView()
                .environmentObject(settings)
        }
    }
}
