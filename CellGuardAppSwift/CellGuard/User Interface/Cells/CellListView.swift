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

struct CellListView: View {
    
    @State private var isShowingFilterView = false
    @State private var isShowingDateSheet = false
    @State var settings: CellListFilterSettings
    
    @State private var sheetDate = Date()
    @Environment(\.managedObjectContext) var managedObjectContext
    
    init(settings: CellListFilterSettings = CellListFilterSettings()) {
        self._settings = State(initialValue: settings)
    }
    
    var body: some View {
        VStack {
            // A workaround for that the NavigationLink on iOS does not respect the isShowingFilterView variable if it's embedded into a ToolbarItem.
            // See: https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-programmatic-navigation-in-swiftui
            // TODO: Upon pressing Apply the view sometimes forgets its origin (check view changes of the base NavigationView & this view)
            NavigationLink(isActive: $isShowingFilterView) {
                CellListFilterView(settingsBound: $settings) {
                    // Somehow this does not work on iOS 14 if a sub navigation has been opened by the filter settings
                    isShowingFilterView = false
                }
            } label: {
                EmptyView()
            }
            FilteredCellView(settings: settings)
        }
        .navigationTitle("Cells")
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
            SelectCellDateView(
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

private struct SelectCellDateView: View {
    
    @Binding var settings: CellListFilterSettings
    @Binding var sheetDate: Date
    @Binding var isShowingDateSheet: Bool
    
    @FetchRequest
    private var firstMeasurement: FetchedResults<CellTweak>
    
    @FetchRequest
    private var lastMeasurement: FetchedResults<CellTweak>
    
    init(settings: Binding<CellListFilterSettings>, sheetDate: Binding<Date>, isShowingDateSheet: Binding<Bool>) {
        self._settings = settings
        self._sheetDate = sheetDate
        self._isShowingDateSheet = isShowingDateSheet
        
        let firstMeasurementRequest: NSFetchRequest<CellTweak> = CellTweak.fetchRequest()
        firstMeasurementRequest.fetchLimit = 1
        firstMeasurementRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CellTweak.collected, ascending: true)]
        firstMeasurementRequest.propertiesToFetch = ["collected"]
        self._firstMeasurement = FetchRequest(fetchRequest: firstMeasurementRequest)
        
        let lastMeasurementRequest: NSFetchRequest<CellTweak> = CellTweak.fetchRequest()
        lastMeasurementRequest.fetchLimit = 1
        lastMeasurementRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CellTweak.collected, ascending: false)]
        lastMeasurementRequest.propertiesToFetch = ["collected"]
        self._lastMeasurement = FetchRequest(fetchRequest: lastMeasurementRequest)
    }
    
    var dateRange: ClosedRange<Date> {
        let start = firstMeasurement.first?.collected ?? Date.distantPast
        let end = lastMeasurement.first?.collected ?? Date()
        return start...end
    }
    
    var body: some View {
        VStack {
            Text("Select Date")
                .font(.headline)
            Text("Choose a date to inspect cells")
                .font(.subheadline)
                .padding([.bottom], 40)
            
            DatePicker("Cell Date", selection: $sheetDate, in: dateRange, displayedComponents: [.date])
                .datePickerStyle(.graphical)
            
            Button {
                let selectedDate: Date
                if let lastDate = lastMeasurement.first?.collected {
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
        return NavigationLink {
            // The first entry should also update to include newer cell measurements
            CellDetailsView(
                // The init method of the GroupedMeasurement class guarantees that each instance contains at least one measurement
                tweakCell: cellMeasurements.measurements.first!,
                predicate: cellMeasurements.detailsPredicate()
            )
        } label: {
            ListPacketCell(measurements: cellMeasurements)
        }
    }
    
}

private struct ListPacketCell: View {
    
    let measurements: GroupedMeasurements
    
    var body: some View {
        let cell = measurements.measurements.first!
        let (countryName, networkName) = OperatorDefinitions.shared.translate(country: cell.country, network: cell.network, iso: true)
        
        let calendar = Calendar.current
        let sameDay = calendar.startOfDay(for: measurements.start) == calendar.startOfDay(for: measurements.end)
        
        let count = GroupedMeasurements.countByStatus(measurements.measurements)
                
        VStack {
            HStack {
                Text(networkName ?? formatMNC(cell.network))
                    .bold()
                + Text(" (\(countryName ?? "\(cell.country)"))")
                + Text(" \(cell.technology ?? "")")
                    .foregroundColor(.gray)
                
                Spacer()
            }
            // TODO: This only updates, when a new cell arrives -> We would have to fetch it from the database
            HStack {
                Text(verbatim: "\(cell.area) / \(cell.cell)")
                Group {
                    if count.pending > 0 {
                        Image(systemName: "arrow.clockwise.circle")
                        Text("\(count.pending) ")
                    }
                    if count.untrusted > 0 {
                        Image(systemName: "exclamationmark.shield")
                        Text("\(count.untrusted) ")
                    }
                    if count.suspicious > 0 {
                        Image(systemName: "shield")
                        Text("\(count.suspicious) ")
                    }
                    if count.trusted > 0 {
                        Image(systemName: "lock.shield")
                        Text("\(count.trusted) ")
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
        NavigationView {
            CellListView()
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
