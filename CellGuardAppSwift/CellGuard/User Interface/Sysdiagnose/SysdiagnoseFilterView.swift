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

    @Published var filenames: [String] = []
    @Published var archiveIdentifier: String?
    @Published var sourceIdentifier: String?
    @Published var basebandChipset: String?
    @Published var productBuildVersion: String?

    func reset() {
        date = Calendar.current.startOfDay(for: Date())
        timeFrame = .live
        filenames = []
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

        if !filenames.isEmpty {
            predicateList.append(NSCompoundPredicate(
                orPredicateWithSubpredicates: filenames.map { NSPredicate(format: "filename == %@", $0 as NSString) }))
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
            ListNavigationLink(value: SysdiagnoseNavigationPath.filterFilenames) {
                HStack {
                    Text("Filenames")
                    Spacer()
                    Text("\(settings.filenames.count)")
                        .foregroundColor(.gray)
                }
            }
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

struct SysdiagnoseFilterFilenameView: View {

    @EnvironmentObject private var settings: SysdiagnoseFilterSettings
    @FetchRequest private var allSysdiagnoses: FetchedResults<Sysdiagnose>

    init() {
        let request: NSFetchRequest<Sysdiagnose> = Sysdiagnose.fetchRequest()
        request.propertiesToFetch = ["filename"]
        request.returnsDistinctResults = true
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Sysdiagnose.filename, ascending: false)]
        self._allSysdiagnoses = FetchRequest(fetchRequest: request, animation: .easeOut)
    }

    var body: some View {
        Group {
            if !allSysdiagnoses.isEmpty {
                List(allSysdiagnoses) { sysdiagnose in
                    let filename = sysdiagnose.filename ?? "Empty Name"
                    HStack {
                        Text(filename)
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                            .opacity(settings.filenames.contains(filename) ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if settings.filenames.contains(filename) {
                            settings.filenames = settings.filenames.filter { $0 != filename }
                        } else {
                            settings.filenames.append(filename)
                        }
                    }
                }
            } else {
                Text("No sysdiagnoses imported.")
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .navigationTitle("Filenames")
        .toolbar {
            ToolbarItem {
                Button {
                    settings.filenames = []
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
