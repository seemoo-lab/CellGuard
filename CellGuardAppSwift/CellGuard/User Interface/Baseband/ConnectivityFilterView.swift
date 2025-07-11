//
//  CellListFilterView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.07.23.
//

import CoreData
import SwiftUI

struct ConnectivityListFilterSettings {
    var date: Date = Calendar.current.startOfDay(for: Date())
    var timeFrame: ConnectivityListFilterTimeFrame = .live
    var simSlot: ConnectivityListFilterSimSlot = .all
    var active: Bool?

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

enum ConnectivityListFilterTimeFrame: String, CaseIterable, Identifiable {
    case live, pastDay, pastDays

    var id: Self { self }
}

enum ConnectivityListFilterSimSlot: UInt8, CaseIterable, Identifiable {
    case all, slot1, slot2, none

    var id: Self { self }

    var slotNumber: Int? {
        switch self {
        case .slot1:
            return 1
        case .slot2:
            return 2
        case .none:
            return 0
        default:
            return nil
        }
    }
}

struct ConnectivityListFilterView: View {
    let close: () -> Void

    @Binding var settingsBound: ConnectivityListFilterSettings
    @State var settings: ConnectivityListFilterSettings = ConnectivityListFilterSettings()

    init(settingsBound: Binding<ConnectivityListFilterSettings>, close: @escaping () -> Void) {
        self.close = close
        self._settingsBound = settingsBound
        self._settings = State(wrappedValue: self._settingsBound.wrappedValue)
    }

    var body: some View {
        ConnectivityListFilterSettingsView(settings: $settings, save: {
            self.settingsBound = settings
            self.close()
        })
        .navigationTitle("Filter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                // TOOD: Somehow taps on it result in the navigation stack disappearing on iOS 14
                if #available(iOS 15, *) {
                    Button {
                        self.settingsBound = settings
                        self.close()
                    } label: {
                        Text("Apply")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct ConnectivityListFilterSettingsView: View {

    @Binding var settings: ConnectivityListFilterSettings
    let save: () -> Void

    var body: some View {
        // TODO: Somehow the Pickers that open a navigation selection menu pose an issue for the navigation bar on iOS 14
        // If the "Apply" button is pressed afterwards, the "< Back" button vanishes from the navigation bar
        Form {
            Section(header: Text("Connectivity Events")) {
                // See: https://stackoverflow.com/a/59348094
                Picker("Connection", selection: $settings.active) {
                    Text("All").tag(nil as Bool?)
                    Text("Connected").tag(true)
                    Text("Disconnected").tag(false)
                }
                Picker("SIM Slot", selection: $settings.simSlot) {
                    ForEach(ConnectivityListFilterSimSlot.allCases) { Text(String(describing: $0).capitalized) }
                }
            }
            if #unavailable(iOS 15) {
                Button {
                    save()
                } label: {
                    HStack {
                        Image(systemName: "tray.and.arrow.down")
                        Text("Apply")
                        Spacer()
                    }
                }
            }
        }
    }

}

struct ConnectivityListFilterView_Previews: PreviewProvider {
    static var previews: some View {
        @State var settings = CellListFilterSettings()

        NavigationView {
            CellListFilterView(settingsBound: $settings) {
                // Doing nothing
            }
        }
    }
}
