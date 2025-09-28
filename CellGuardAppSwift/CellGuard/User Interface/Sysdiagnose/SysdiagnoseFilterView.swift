//
//  CellListFilterView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.07.23.
//

import CoreData
import SwiftUI
import NavigationBackport

class SysdiagnoseFilterSettings: ObservableObject {
    @Published var date: Date = Calendar.current.startOfDay(for: Date())
    @Published var timeFrame: FilterTimeFrame = .live

    @Published var filename: String?
    @Published var archiveIdentifier: String?
    @Published var sourceIdentifier: String?
    @Published var basebandChipset: String?
    @Published var productBuildVersion: String?

    func reset() {
        date = Calendar.current.startOfDay(for: Date())
        timeFrame = .live
        filename = nil
        archiveIdentifier = nil
        sourceIdentifier = nil
        basebandChipset = nil
        productBuildVersion = nil
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
            predicateList.append(NSPredicate(format: "%@ <= imported", start as NSDate))
        }
        if let end = endDate {
            predicateList.append(NSPredicate(format: "imported <= %@", end as NSDate))
        }

        if let filename = filename {
            predicateList.append(NSPredicate(format: "filename == %@", filename as NSString))
        }
        if let archiveIdentifier = archiveIdentifier {
            predicateList.append(NSPredicate(format: "archiveIdentifier == %@", archiveIdentifier as NSString))
        }
        if let sourceIdentifier = sourceIdentifier {
            predicateList.append(NSPredicate(format: "sourceIdentifier == %@", sourceIdentifier as NSString))
        }
        if let basebandChipset = basebandChipset {
            predicateList.append(NSPredicate(format: "basebandChipset == %@", basebandChipset as NSString))
        }
        if let productBuildVersion = productBuildVersion {
            predicateList.append(NSPredicate(format: "productBuildVersion == %@", productBuildVersion as NSString))
        }

        return predicateList
    }

    func applyTo(request: NSFetchRequest<Sysdiagnose>) {
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

struct SysdiagnoseListFilterView: View {

    var body: some View {
        SysdiagnoseListFilterSettingsView()
        .navigationTitle("Filter")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SysdiagnoseListFilterSettingsView: View {

    @EnvironmentObject var settings: SysdiagnoseFilterSettings

    var body: some View {
        Form {
            Section(header: Text("Sysdiagnoses")) {
                DistinctStringPicker<Sysdiagnose>(
                    selection: $settings.filename,
                    attribute: \.filename,
                    attributeName: "filename",
                    title: "Filename",
                )
                DistinctStringPicker<Sysdiagnose>(
                    selection: $settings.archiveIdentifier,
                    attribute: \.archiveIdentifier,
                    attributeName: "archiveIdentifier",
                    title: "Archive Identifier",
                )
                DistinctStringPicker<Sysdiagnose>(
                    selection: $settings.sourceIdentifier,
                    attribute: \.sourceIdentifier,
                    attributeName: "sourceIdentifier",
                    title: "Source Identifier",
                )
                DistinctStringPicker<Sysdiagnose>(
                    selection: $settings.basebandChipset,
                    attribute: \.basebandChipset,
                    attributeName: "basebandChipset",
                    title: "Baseband Chipset",
                )
                DistinctStringPicker<Sysdiagnose>(
                    selection: $settings.productBuildVersion,
                    attribute: \.productBuildVersion,
                    attributeName: "productBuildVersion",
                    title: "iOS Build Version",
                )
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

struct SysdiagnoseListFilterView_Previews: PreviewProvider {
    static var previews: some View {
        @State var settings = SysdiagnoseFilterSettings()

        NBNavigationStack {
            SysdiagnoseListFilterView()
                .environmentObject(settings)
        }
    }
}
