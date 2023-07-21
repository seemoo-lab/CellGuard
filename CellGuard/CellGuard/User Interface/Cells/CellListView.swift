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
    
    var body: some View {
        NavigationView {
            VStack {
                // A workaround for that the NavigationLink on iOS does not respect the isShowingFilterView variable if it's embedded into a ToolbarItem.
                // See: https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-programmatic-navigation-in-swiftui
                NavigationLink(isActive: $isShowingFilterView) {
                    Button("Close") {
                        isShowingFilterView = false
                    }
                } label: {
                    EmptyView()
                }
                FilteredCellView()
            }
            .navigationTitle("Cells")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingFilterView = true
                    } label: {
                        // Starting with iOS 15: line.3.horizontal.decrease.circle
                        Image(systemName: "line.horizontal.3.decrease.circle")
                    }
                }
            }
        }
        // Magic that prevents Pickers from closing
        // See: https://stackoverflow.com/a/70307271
        .navigationViewStyle(.stack)
    }
}

private enum GroupedMeasurementsError: Error {
    case emptyList
    case missingStartDate
    case missingEndDate
}

private struct GroupedMeasurements: Identifiable {
    
    let measurements: [TweakCell]
    let start: Date
    let end: Date
    let id: Int
    
    init(measurements: [TweakCell]) throws {
        // We require that the list contains at least one element
        if measurements.isEmpty {
            throw GroupedMeasurementsError.emptyList
        }
        self.measurements = measurements
        
        // We assume the measurements are sorted in descending order based on their timestamp
        guard let end = measurements.first?.collected else {
            throw GroupedMeasurementsError.missingEndDate
        }
        guard let start = measurements.last?.collected else {
            throw GroupedMeasurementsError.missingStartDate
        }
        self.start = start
        self.end = end
        
        // Use the list's hash value to identify the list
        // See: https://stackoverflow.com/a/68068346
        self.id = measurements.hashValue
    }
    
}

private struct FilteredCellView: View {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: FilteredCellView.self)
    )
    
    @FetchRequest
    private var measurements: FetchedResults<TweakCell>
    
    init() {
        let cellsRequest: NSFetchRequest<TweakCell> = TweakCell.fetchRequest()
        cellsRequest.fetchBatchSize = 25
        cellsRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TweakCell.collected, ascending: false)]
        // TODO: Replace with filter (filter.applyTo(qmi: qmiRequest))
        cellsRequest.predicate = NSPredicate(format: "collected >= %@", Calendar.current.startOfDay(for: Date()) as NSDate)
        
        self._measurements = FetchRequest(fetchRequest: cellsRequest, animation: .easeOut)
    }
    
    private func groupMeasurements() -> [GroupedMeasurements] {
        let queryCell = PersistenceController.shared.queryCell
        var groups: [GroupedMeasurements] = []
        
        // Iterate through all measurements and start a new group upon encountering a new cell
        var groupMeasurements: [TweakCell] = []
        for measurement in measurements {
            // If we've encountered a new cell, we start a new group
            if let firstGroupMeasurement = groupMeasurements.first, queryCell(firstGroupMeasurement) != queryCell(measurement) {
                do {
                    groups.append(try GroupedMeasurements(measurements: groupMeasurements))
                } catch {
                    Self.logger.warning("Can't group cell measurements (\(groupMeasurements)): \(error)")
                }
                groupMeasurements = []
            }
            
            // In any case, we append the cell measurement
            groupMeasurements.append(measurement)
        }
        
        // The final batch of measurements
        if !groupMeasurements.isEmpty {
            do {
                groups.append(try GroupedMeasurements(measurements: groupMeasurements))
            } catch {
                Self.logger.warning("Can't group cell measurements (\(groupMeasurements)): \(error)")
            }
        }
        
        return groups
    }
    
    var body: some View {
        List(groupMeasurements()) { cellMeasurements in
            NavigationLink {
                // TODO: Rework
                CellDetailsView(cell: cellMeasurements.measurements.first!)
            } label: {
                ListPacketCell(measurements: cellMeasurements)
            }
        }
        .listStyle(.insetGrouped)
    }
    
}

private struct ListPacketCell: View {
    
    let measurements: GroupedMeasurements
    
    var body: some View {
        // TODO: Bottom Right Verification Counts (check, warn, error)
        Text("TODO")
    }
    
}
