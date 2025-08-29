//
//  CellListFilterView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.07.23.
//

import CoreData
import SwiftUI
import NavigationBackport

class CellListFilterSettings: ObservableObject {

    @Published var status: CellListFilterStatus = .all
    @Published var study: CellListFilterStudyOptions = .all

    @Published var timeFrame: FilterTimeFrame = .live
    @Published var date: Date = Calendar.current.startOfDay(for: Date())

    @Published var technology: ALSTechnology?
    @Published var simSlot: FilterSimSlot = .all
    @Published var country: Int?
    @Published var network: Int?
    @Published var area: Int?
    @Published var cell: Int?

    func reset() {
        status = .all
        study = .all

        timeFrame = .live
        date = Calendar.current.startOfDay(for: Date())

        technology = nil
        simSlot = .all
        country = nil
        network = nil
        area = nil
        cell = nil
    }

    func predicates(startDate: Date?, endDate: Date?) -> [NSPredicate] {
        var predicateList: [NSPredicate] = [
            NSPredicate(format: "cell != nil"),
            NSPredicate(format: "pipeline == %@", Int(primaryVerificationPipeline.id) as NSNumber)
        ]

        if let technology = technology {
            predicateList.append(NSPredicate(format: "cell.technology == %@", technology.rawValue))
        }

        if let slotNumber = simSlot.slotNumber {
            predicateList.append(NSPredicate(format: "cell.simSlotID == %@", NSNumber(value: slotNumber)))
        }

        if let country = country {
            predicateList.append(NSPredicate(format: "cell.country == %@", country as NSNumber))
        }

        if let network = network {
            predicateList.append(NSPredicate(format: "cell.network == %@", network as NSNumber))
        }

        if let area = area {
            predicateList.append(NSPredicate(format: "cell.area == %@", area as NSNumber))
        }

        if let cell = cell {
            predicateList.append(NSPredicate(format: "cell.cell == %@", cell as NSNumber))
        }

        if let start = startDate {
            predicateList.append(NSPredicate(format: "%@ <= cell.collected", start as NSDate))
        }
        if let end = endDate {
            predicateList.append(NSPredicate(format: "cell.collected <= %@", end as NSDate))
        }

        let thresholdSuspicious = primaryVerificationPipeline.pointsSuspicious as NSNumber
        let thresholdUntrusted = primaryVerificationPipeline.pointsUntrusted as NSNumber

        switch status {
        case .all:
            break
        case .processing:
            predicateList.append(NSPredicate(format: "finished == NO"))
        case .trusted:
            predicateList.append(NSPredicate(format: "finished == YES"))
            predicateList.append(NSPredicate(format: "score >= %@", thresholdSuspicious))
        case .anomalous:
            predicateList.append(NSPredicate(format: "finished == YES"))
            predicateList.append(NSPredicate(format: "score >= %@ and score < %@", thresholdUntrusted, thresholdSuspicious))
        case .suspicious:
            predicateList.append(NSPredicate(format: "finished == YES"))
            predicateList.append(NSPredicate(format: "score < %@", thresholdUntrusted))
        }

        switch study {
        case .all:
            break
        case .submitted:
            predicateList.append(NSPredicate(format: "cell.study != nil and cell.study.uploaded != nil"))
        }

        return predicateList
    }

    func applyTo(request: NSFetchRequest<VerificationState>) {
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
        request.relationshipKeyPathsForPrefetching = ["cell"]
    }

}

enum CellListFilterStatus: String, CaseIterable, Identifiable {
    case all, processing, trusted, anomalous, suspicious

    var id: Self { self }
}

enum CellListFilterCustomOptions: String, CaseIterable, Identifiable {
    case all, custom

    var id: Self { self }
}

enum CellListFilterPredefinedOptions: String, CaseIterable, Identifiable {
    case all, predefined, custom

    var id: Self { self }
}

enum CellListFilterStudyOptions: String, CaseIterable, Identifiable {
    case all, submitted

    var id: Self { self }
}

struct CellListFilterView: View {

    var body: some View {
        CellListFilterSettingsView()
        .navigationTitle("Filter")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CellListFilterSettingsView: View {

    @EnvironmentObject private var settings: CellListFilterSettings

    var body: some View {
        Form {
            Section(header: Text("Cells")) {
                // See: https://stackoverflow.com/a/59348094
                Picker("Technology", selection: $settings.technology) {
                    Text("All").tag(nil as ALSTechnology?)
                    ForEach(ALSTechnology.allCases) { Text($0.rawValue).tag($0 as ALSTechnology?) }
                }
                Picker("SIM Slot", selection: $settings.simSlot) {
                    ForEach(FilterSimSlot.allCases) { Text(String(describing: $0).capitalized) }
                }

                LabelNumberField("Country", "MCC", $settings.country)
                LabelNumberField("Network", "MNC", $settings.network)
                LabelNumberField("Area", "LAC or TAC", $settings.area)
                LabelNumberField("Cell", "Cell ID", $settings.cell)
            }
            Section(header: Text("Verification")) {
                Picker("Status", selection: $settings.status) {
                    ForEach(CellListFilterStatus.allCases) { Text($0.rawValue.capitalized) }
                }
            }
            Section(header: Text("Data")) {
                Picker("Display", selection: $settings.timeFrame) {
                    Text("Live").tag(FilterTimeFrame.live)
                    Text("Recorded").tag(FilterTimeFrame.pastDay)
                }
                if settings.timeFrame == .pastDay {
                    DatePicker("Day", selection: $settings.date, in: ...Date(), displayedComponents: [.date])
                }
            }

            Section(header: Text("Study")) {
                Picker("Status", selection: $settings.study) {
                    Text("All").tag(CellListFilterStudyOptions.all)
                    Text("Submitted").tag(CellListFilterStudyOptions.submitted)
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

struct CellListFilterView_Previews: PreviewProvider {
    static var previews: some View {
        @State var settings = CellListFilterSettings()

        NBNavigationStack {
            CellListFilterView()
        }
        .environmentObject(settings)
    }
}
