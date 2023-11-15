//
//  CellSummaryView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 01.08.23.
//

import CoreData
import SwiftUI

struct DataSummaryView: View {
    
    @State var start: Date = Calendar.current.startOfDay(for: Date())
    @State var end: Date = Date()
    @State var updateInProgress: Bool = false
    
    @State var measurements: (first: Date?, last: Date?, pending: Int?, untrusted: Int?, suspicious: Int?, trusted: Int?) = (nil, nil, nil, nil, nil, nil)
    @State var cells: (pending: Int?, untrusted: Int?, suspicious: Int?, trusted: Int?) = (nil, nil, nil, nil)
    @State var alsCellsCount: Int? = nil
    @State var packets: (first: Date?, last: Date?, qmi: Int?, ari: Int?) = (nil, nil, nil, nil)
    @State var locations: (first: Date?, last: Date?, count: Int?) = (nil, nil, nil)
    
    var body: some View {
        List {
            Section(header: Text("Parameters")) {
                DatePicker("Start", selection: $start, displayedComponents: [.date, .hourAndMinute])
                DatePicker("End", selection: $end, displayedComponents: [.date, .hourAndMinute])
                Button {
                    update()
                } label: {
                    HStack {
                        Text("Update")
                        Spacer()
                        if updateInProgress {
                            ProgressView()
                        }
                    }
                }
                .disabled(updateInProgress)
            }
            Section(header: Text("Collected Measurements")) {
                CellDetailsRow("First", dateStringOrNil(date: measurements.first))
                CellDetailsRow("Last", dateStringOrNil(date: measurements.last))
                if let first = measurements.first, let last = measurements.last {
                    CellDetailsRow("Days", Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0)
                }
                CellDetailsRow("Pending", measurements.pending ?? 0)
                CellDetailsRow("Untrusted", measurements.untrusted ?? 0)
                CellDetailsRow("Suspicious", measurements.suspicious ?? 0)
                CellDetailsRow("Trusted", measurements.trusted ?? 0)
            }
            Section(header: Text("Collected Cells")) {
                CellDetailsRow("Pending", cells.pending ?? 0)
                CellDetailsRow("Untrusted", cells.untrusted ?? 0)
                CellDetailsRow("Suspicious", cells.suspicious ?? 0)
                CellDetailsRow("Trusted", cells.trusted ?? 0)
            }
            Section(header: Text("ALS Cells")) {
                CellDetailsRow("Count", alsCellsCount ?? 0)
            }
            Section(header: Text("Packets")) {
                CellDetailsRow("First", dateStringOrNil(date: packets.first))
                CellDetailsRow("Last", dateStringOrNil(date: packets.last))
                CellDetailsRow("QMI Packets", packets.qmi ?? 0)
                CellDetailsRow("ARI Packets", packets.ari ?? 0)
            }
            Section(header: Text("Locations")) {
                CellDetailsRow("First", dateStringOrNil(date: locations.first))
                CellDetailsRow("Last", dateStringOrNil(date: locations.last))
                CellDetailsRow("Count", locations.count ?? 0)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Stats")
        .onAppear() {
            // TODO: Timer for periodically updating the stuff
            update()
        }
    }
    
    private func dateStringOrNil(date: Date?) -> String {
        if let date = date {
            return mediumDateTimeFormatter.string(from: date)
        } else {
            return "nil"
        }
    }
    
    private func update() {
        updateInProgress = true
        Task(priority: .utility) {
            let persistence = PersistenceController.shared
            
            let collectedPredicate = NSPredicate(format: "collected >= %@ and collected <= %@", start as NSDate, end as NSDate)
            
            let measurementCellsResults = try persistence.performAndWait { context in
                let fetchMeasurements: NSFetchRequest<TweakCell> = TweakCell.fetchRequest()
                fetchMeasurements.sortDescriptors = [NSSortDescriptor(keyPath: \TweakCell.collected, ascending: true)]
                fetchMeasurements.propertiesToFetch = ["score", "status"]
                fetchMeasurements.predicate = collectedPredicate
                let measurements = try context.fetch(fetchMeasurements)
                
                var measurementsUntrusted = 0
                var measurementsSuspicious = 0
                var measurementsTrusted = 0
                var measurementsPending = 0
                
                for measurement in measurements {
                    if measurement.status != CellStatus.verified.rawValue {
                        measurementsPending += 1
                        continue
                    }
                    
                    if measurement.score >= CellVerifier.pointsSuspiciousThreshold {
                        measurementsTrusted += 1
                    } else if measurement.score >= CellVerifier.pointsUntrustedThreshold {
                        measurementsSuspicious += 1
                    } else {
                        measurementsUntrusted += 1
                    }
                }
                
                let cells = Dictionary(grouping: measurements, by: { PersistenceController.queryCell(from: $0) })
                
                var cellsUntrusted = 0
                var cellsSuspicious = 0
                var cellsPending = 0
                var cellsVerified = 0
                
                for (_, measurements) in cells {
                    if measurements.first(where: { $0.status == CellStatus.verified.rawValue && $0.score < CellVerifier.pointsUntrustedThreshold }) != nil {
                        cellsUntrusted += 1
                        continue
                    }
                    
                    if measurements.first(where: { $0.status == CellStatus.verified.rawValue && $0.score < CellVerifier.pointsSuspiciousThreshold && $0.score >= CellVerifier.pointsUntrustedThreshold}) != nil {
                        cellsSuspicious += 1
                        continue
                    }
                    
                    if measurements.first(where: { $0.status != CellStatus.verified.rawValue }) != nil {
                        cellsPending += 1
                        continue
                    }
                    
                    cellsVerified += 1
                }
                
                return (
                    measurements: (measurements.first?.collected, measurements.last?.collected, measurementsPending, measurementsUntrusted, measurementsSuspicious, measurementsTrusted),
                    cells: (cellsPending, cellsUntrusted, cellsSuspicious, cellsVerified)
                )
            }
            
            guard let measurementCellsResults = measurementCellsResults else {
                print("No Measurements & Cells ):")
                return
            }
            
            let locations = try persistence.performAndWait { context in
                let locationRequest: NSFetchRequest<UserLocation> = UserLocation.fetchRequest()
                locationRequest.sortDescriptors = [NSSortDescriptor(keyPath: \UserLocation.collected, ascending: true)]
                locationRequest.predicate = collectedPredicate
                
                let locations = try context.fetch(locationRequest)
                
                return (locations.first?.collected, locations.last?.collected, locations.count)
            }
            
            guard let locations = locations else {
                print("No Locations ):")
                return
            }
            
            let alsCellCount = persistence.countEntitiesOf(ALSCell.fetchRequest() as NSFetchRequest<ALSCell>)
            
            guard let alsCellCount = alsCellCount else {
                print("No ALS cells ):")
                return
            }
            
            let packets: (first: Date?, last: Date?, qmi: Int?, ari: Int?)? = try persistence.performAndWait { context in
                let qmiRequest: NSFetchRequest<QMIPacket> = QMIPacket.fetchRequest()
                qmiRequest.predicate = collectedPredicate
                qmiRequest.includesSubentities = false
                let qmiPacketCount = try context.count(for: qmiRequest)
                
                let ariRequest: NSFetchRequest<ARIPacket> = ARIPacket.fetchRequest()
                ariRequest.predicate = collectedPredicate
                ariRequest.includesSubentities = false
                let ariPacketCount = try context.count(for: ariRequest)
                
                if qmiPacketCount > 0 {
                    let firstQMIRequest: NSFetchRequest<QMIPacket> = QMIPacket.fetchRequest()
                    firstQMIRequest.sortDescriptors = [NSSortDescriptor(keyPath: \QMIPacket.collected, ascending: true)]
                    firstQMIRequest.fetchLimit = 1
                    
                    let lastQMIRequest: NSFetchRequest<QMIPacket> = QMIPacket.fetchRequest()
                    lastQMIRequest.sortDescriptors = [NSSortDescriptor(keyPath: \QMIPacket.collected, ascending: false)]
                    lastQMIRequest.fetchLimit = 1
                    
                    return (
                        try context.fetch(firstQMIRequest).first?.collected,
                        try context.fetch(lastQMIRequest).first?.collected,
                        qmiPacketCount,
                        ariPacketCount
                    )
                } else {
                    let firstARIRequest: NSFetchRequest<ARIPacket> = ARIPacket.fetchRequest()
                    firstARIRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ARIPacket.collected, ascending: true)]
                    firstARIRequest.fetchLimit = 1
                    
                    let lastARIRequest: NSFetchRequest<ARIPacket> = ARIPacket.fetchRequest()
                    lastARIRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ARIPacket.collected, ascending: false)]
                    lastARIRequest.fetchLimit = 1
                    
                    return (
                        try context.fetch(firstARIRequest).first?.collected,
                        try context.fetch(lastARIRequest).first?.collected,
                        qmiPacketCount,
                        ariPacketCount
                    )
                }
            }
            
            guard let packets = packets else {
                print("No Packets ):")
                return
            }
            
            DispatchQueue.main.async {
                self.measurements = measurementCellsResults.measurements
                self.cells = measurementCellsResults.cells
                self.locations = locations
                self.alsCellsCount = alsCellCount
                self.packets = packets
                self.updateInProgress = false
            }
        }
    }
}

struct DataSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        DataSummaryView()
    }
}
