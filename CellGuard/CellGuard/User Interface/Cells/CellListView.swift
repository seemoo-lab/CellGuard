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
    @State private var settings = CellListFilterSettings()
    
    @State private var sheetDate = Date()
    
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    sheetDate = settings.date
                    isShowingDateSheet.toggle()
                } label: {
                    Image(systemName: "calendar")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isShowingFilterView = true
                } label: {
                    // Starting with iOS 15: line.3.horizontal.decrease.circle
                    Image(systemName: "line.horizontal.3.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $isShowingDateSheet) {
            VStack {
                Text("Select Date")
                    .font(.headline)
                Text("Choose a date to inspect cells")
                    .font(.subheadline)
                    .padding([.bottom], 40)
                
                DatePicker("Cell Date", selection: $sheetDate, in: Date.distantPast...Date(), displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                
                Button {
                    let startOfToday = Calendar.current.startOfDay(for: Date())
                    let startOfDate = Calendar.current.startOfDay(for: sheetDate)
                    settings.timeFrame = startOfToday == startOfDate ? .live : .past
                    settings.date = sheetDate
                    isShowingDateSheet.toggle()
                } label: {
                    Text("Apply")
                        .bold()
                }
                .padding([.top], 40)
            }
            .padding()
        }
        // Magic that prevents Pickers from closing
        // See: https://stackoverflow.com/a/70307271
        .navigationViewStyle(.stack)
    }
}

private struct FilteredCellView: View {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: FilteredCellView.self)
    )
    
    @FetchRequest
    private var measurements: FetchedResults<TweakCell>
    
    init(settings: CellListFilterSettings) {
        let cellsRequest: NSFetchRequest<TweakCell> = TweakCell.fetchRequest()
        // cellsRequest.fetchBatchSize = 25
        cellsRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TweakCell.collected, ascending: false)]
        settings.applyTo(request: cellsRequest)
        
        self._measurements = FetchRequest(fetchRequest: cellsRequest, animation: .easeOut)
    }
    
    private func groupMeasurements() -> [GroupedMeasurements] {
        // TODO: Also group by day?
        let queryCell = PersistenceController.queryCell
        var groups: [GroupedMeasurements] = []
        
        // Iterate through all measurements and start a new group upon encountering a new cell
        var groupMeasurements: [TweakCell] = []
        var first = true
        for measurement in measurements {
            // If we've encountered a new cell, we start a new group
            if let firstGroupMeasurement = groupMeasurements.first, queryCell(firstGroupMeasurement) != queryCell(measurement) {
                do {
                    groups.append(try GroupedMeasurements(measurements: groupMeasurements, openEnd: first))
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
                groups.append(try GroupedMeasurements(measurements: groupMeasurements, openEnd: first))
            } catch {
                Self.logger.warning("Can't group cell measurements (\(groupMeasurements)): \(error)")
            }
        }
        
        return groups
    }
    
    var body: some View {
        let groupedMeasurements = groupMeasurements()
        if !groupedMeasurements.isEmpty {
            List(groupedMeasurements) { cellMeasurements in
                NavigationLink {
                    // The first entry should also update to include newer cell measurements
                    CellDetailsView(
                        // The init method of the GroupedMeasurement class guarantees that each instance contains at least one measurement
                        cell: cellMeasurements.measurements.first!,
                        start: cellMeasurements.start,
                        end: cellMeasurements.openEnd ? nil : cellMeasurements.end
                    )
                } label: {
                    ListPacketCell(measurements: cellMeasurements)
                }
            }
            .listStyle(.insetGrouped)
        } else {
            Text("No cell measurements match your search criteria.")
                .multilineTextAlignment(.center)
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
        
        let count = GroupedMeasurements.countByStatus(measurements: measurements.measurements)
                
        VStack {
            HStack {
                Text(networkName ?? "\(cell.network)")
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
