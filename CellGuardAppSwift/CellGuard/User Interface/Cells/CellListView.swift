//
//  CellListView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 21.07.23.
//

import CoreData
import Foundation
import SwiftUI
import OSLog
import NavigationBackport

struct CellListView: View {

    @State private var isShowingDateSheet = false
    @State private var sheetRange = Date.distantPast...Date.distantFuture

    @EnvironmentObject private var navigator: PathNavigator
    @EnvironmentObject private var settings: CellListFilterSettings

    private func updateDateRange() {
        Task.detached {
            if let range = await PersistenceController.basedOnEnvironment().fetchCellDateRange() {
                await MainActor.run {
                    settings.showLatestDate(range: range)
                    sheetRange = range
                }
            }
        }
    }

    var body: some View {
        FilteredCellView(settings: settings)
        .navigationTitle("Cells")
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
                    navigator.push(SummaryNavigationPath.cellListFilter)
                } label: {
                    Image(systemName: CGIcons.filter)
                }
            }
        }
        .sheet(isPresented: $isShowingDateSheet) {
            SelectDateSheet(timeFrame: $settings.timeFrame, date: $settings.date, sheetRange: $sheetRange)
                .onAppear { updateDateRange() }
        }
        .onAppear { updateDateRange() }
    }
}

private func dateSheetDateBinding(settings: CellListFilterSettings, sheetRange: ClosedRange<Date>) -> Binding<Date> {
    Binding {
        settings.date
    } set: { newDate in
        let dateInBounds = newDate > sheetRange.upperBound ? sheetRange.upperBound : newDate
        let startOfDate: Date = Calendar.current.startOfDay(for: dateInBounds)
        let startOfToday = Calendar.current.startOfDay(for: Date())

        settings.timeFrame = startOfToday == startOfDate ? .live : .pastDay
        settings.date = dateInBounds
    }
}

private struct CompactDateSheet: View {

    @EnvironmentObject private var settings: CellListFilterSettings
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Binding var sheetRange: ClosedRange<Date>

    var body: some View {
        // We're using a uniform height for the DatePicker and the sheet
        // See: https://stackoverflow.com/a/75544690
        // We're adding a padding to fix a UICalendarView layout constraint warning
        // See: https://stackoverflow.com/a/77669538
        DatePicker("Cell Date", selection: dateBinding, in: sheetRange, displayedComponents: [.date])
            .datePickerStyle(.graphical)
            .frame(
                maxHeight: horizontalSizeClass == .compact ? 400 : 500,
            )
            .padding()
    }

    var dateBinding: Binding<Date> {
        dateSheetDateBinding(settings: settings, sheetRange: sheetRange)
    }
}

private struct ExtensiveDateSheet: View {

    @EnvironmentObject private var settings: CellListFilterSettings

    @Binding var sheetRange: ClosedRange<Date>

    var body: some View {
        VStack {
            Text("Select Date")
                .font(.headline)
            Text("Choose a date to inspect cells")
                .font(.subheadline)
                .padding([.bottom], 40)

            DatePicker("Cell Date", selection: dateBinding, in: sheetRange, displayedComponents: [.date])
                .datePickerStyle(.graphical)
        }
        .padding()
    }

    var dateBinding: Binding<Date> {
        dateSheetDateBinding(settings: settings, sheetRange: sheetRange)
    }
}

private struct FilteredCellView: View {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: FilteredCellView.self)
    )

    private let settings: CellListFilterSettings

    @FetchRequest
    private var measurementsStates: FetchedResults<VerificationState>

    init(settings: CellListFilterSettings) {
        self.settings = settings

        let statesRequest: NSFetchRequest<VerificationState> = VerificationState.fetchRequest()
        // cellsRequest.fetchBatchSize = 25
        statesRequest.sortDescriptors = [NSSortDescriptor(key: "cell.collected", ascending: false)]
        settings.applyTo(request: statesRequest)

        self._measurementsStates = FetchRequest(fetchRequest: statesRequest, animation: .easeOut)
    }

    private func groupMeasurements() -> [GroupedMeasurements] {
        let queryCell = PersistenceController.queryCell
        var groups: [GroupedMeasurements] = []

        // Iterate through all measurements and start a new group upon encountering a new cell
        var groupMeasurements: [CellTweak] = []
        var first = true
        for measurementState in measurementsStates {
            // Ensure that a cell is assigned to the state with a request predicate in CellListFilterView
            let measurement = measurementState.cell!

            // If we've encountered a new cell, we start a new group
            if let firstGroupMeasurement = groupMeasurements.first, queryCell(firstGroupMeasurement) != queryCell(measurement) {
                do {
                    groups.append(try GroupedMeasurements(measurements: groupMeasurements, openEnd: first, settings: settings))
                } catch {
                    Self.logger.warning("Can't group cell measurements (\(groupMeasurements)): \(error)")
                }
                first = false
                groupMeasurements = []
            }

            // In any case, we append the cell measurement
            groupMeasurements.append(measurement)
        }

        // The final batch of measurements
        if !groupMeasurements.isEmpty {
            do {
                groups.append(try GroupedMeasurements(measurements: groupMeasurements, openEnd: first, settings: settings))
            } catch {
                Self.logger.warning("Can't group cell measurements (\(groupMeasurements)): \(error)")
            }
        }

        return groups
    }

    private func groupMeasurementsByDay(_ groupedMeasurements: [GroupedMeasurements]) -> [(Date, [GroupedMeasurements])] {
        return Dictionary(grouping: groupedMeasurements) { measurement in
            Calendar.current.startOfDay(for: measurement.start)
        }
        .sorted { groupOne, groupTwo in
            groupOne.key > groupTwo.key
        }
    }

    var body: some View {
        let groupedMeasurements = groupMeasurements()
        if !groupedMeasurements.isEmpty {
            if settings.timeFrame == .pastDays {
                // Split the measurements in to day sections
                List(groupMeasurementsByDay(groupedMeasurements), id: \.0) { (day, dayMeasurements) in
                    Section(header: Text(mediumDateFormatter.string(from: day))) {
                        ForEach(dayMeasurements) { cellMeasurements in
                            GroupedNavigationLink(cellMeasurements: cellMeasurements)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                // Show cells of one day
                List(groupedMeasurements) { cellMeasurements in
                    GroupedNavigationLink(cellMeasurements: cellMeasurements)
                }
                .listStyle(.insetGrouped)
            }

        } else {
            Text("No cells match your query.")
                .multilineTextAlignment(.center)
                .padding()
        }
    }

}

private struct GroupedNavigationLink: View {

    let cellMeasurements: GroupedMeasurements

    var body: some View {
        ListNavigationLink(
            // The first entry should also update to include newer cell measurements
            // The init method of the GroupedMeasurement class guarantees that each instance contains at least one measurement
            value: CellDetailsNavigation(cell: .init(object: cellMeasurements.measurements.first!), predicate: cellMeasurements.detailsPredicate())
        ) {
            ListPacketCell(measurements: cellMeasurements)
        }
    }

}

private struct ListPacketCell: View {

    private let measurements: GroupedMeasurements
    private var simSlots = Set<Int16>()

    init(measurements: GroupedMeasurements) {
        self.measurements = measurements

        for measurement in measurements.measurements {
            simSlots.insert(measurement.simSlotID)
        }
    }

    var body: some View {
        let cell = measurements.measurements.first!
        let netOperators = OperatorDefinitions.shared.translate(country: cell.country, network: cell.network)

        let calendar = Calendar.current
        let sameDay = calendar.startOfDay(for: measurements.start) == calendar.startOfDay(for: measurements.end)

        let (pending, points, pointsMax) = GroupedMeasurements.countByStatus(measurements.measurements)

        VStack {
            HStack {
                Text(netOperators.firstCombinedName ?? formatMNC(cell.network))
                    .bold()
                + Text(" (\(netOperators.combinedIsoString ?? "\(cell.country)"))")
                + Text(" \(cell.technology ?? "")")
                    .foregroundColor(.gray)

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
            // TODO: This only updates, when a new cell arrives -> We would have to fetch it from the database
            HStack {
                Text(verbatim: "\(cell.area) / \(cell.cell)")
                Group {
                    if pending {
                        Image(systemName: "arrow.clockwise.circle")
                    } else {
                        if points >= primaryVerificationPipeline.pointsSuspicious {
                            Image(systemName: "lock.shield")
                        } else if points >= primaryVerificationPipeline.pointsUntrusted {
                            Image(systemName: "shield")
                        } else {
                            Image(systemName: "exclamationmark.shield")
                        }
                        Text("\(points) / \(pointsMax)")
                    }
                }
                .font(.system(size: 14))
                .foregroundColor(.gray)
                Spacer()
            }
            HStack {
                if measurements.measurements.count == 1 {
                    Text(fullMediumDateTimeFormatter.string(from: measurements.start))
                } else {
                    Text(fullMediumDateTimeFormatter.string(from: measurements.start))
                    + Text(" - ")
                    + Text((sameDay ? mediumTimeFormatter : fullMediumDateTimeFormatter).string(from: measurements.end))
                }
                Spacer()
            }
            .font(.system(size: 14))
            .foregroundColor(.gray)
        }
    }

}

struct CellListView_Previews: PreviewProvider {
    static var previews: some View {
        @State var filter = CellListFilterSettings()

        NBNavigationStack {
            CellListView()
                .cgNavigationDestinations(.summaryTab)
                .cgNavigationDestinations(.cells)
                .cgNavigationDestinations(.operators)
                .cgNavigationDestinations(.packets)
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(filter)
    }
}
