//
//  CellDetailsView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 21.07.23.
//

import SwiftUI

struct CellDetailsView: View {
    
    let cell: Cell
    let start: Date?
    let end: Date?
    
    @State private var showAll: Bool
    
    init(cell: Cell) {
        self.cell = cell
        self.start = nil
        self.end = nil
        self._showAll = State(initialValue: true)
    }
    
    init(cell: Cell, start: Date, end: Date?) {
        self.cell = cell
        self.start = start
        self.end = end
        self._showAll = State(initialValue: false)
    }
    
    var body: some View {
        let (alsCellsRequest, measurementsRequest) = fetchRequests()
        
        List {
            TweakCellDetailsMap(alsCells: alsCellsRequest, measurements: measurementsRequest)
            CellDetailsCell(cell: cell)
            TweakCellDetailsMeasurementCount(alsCells: alsCellsRequest, measurements: measurementsRequest)
            // A toolbar item somehow hides the navigation history (back button) upon state change and thus, we use a simple button
            Button {
                showAll = true
            } label: {
                Label("All Measurements", systemImage: "globe")
                    .disabled(showAll)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("\(cell.technology ?? "Unknown") Cell")
    }
    
    private func fetchRequests() -> (FetchRequest<CellALS>, FetchRequest<CellTweak>) {
        let alsCellsRequest = FetchRequest<CellALS>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CellALS.imported, ascending: false)],
            predicate: PersistenceController.shared.sameCellPredicate(cell: cell, mergeUMTS: true),
            animation: .default
        )
        
        var measurementPredicates = [PersistenceController.shared.sameCellPredicate(cell: cell, mergeUMTS: false)]
        if !showAll {
            if let start = start {
                measurementPredicates.append(NSPredicate(format: "collected >= %@", start as NSDate))
            }
            if let end = end {
                measurementPredicates.append(NSPredicate(format: "collected <= %@", end as NSDate))
            }
        }
        let measurementsRequest = FetchRequest<CellTweak>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CellTweak.collected, ascending: false)],
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: measurementPredicates),
            animation: .default
        )
        
        return (alsCellsRequest, measurementsRequest)
    }
    
}

private struct TweakCellDetailsMap: View {
    
    @FetchRequest private var alsCells: FetchedResults<CellALS>
    @FetchRequest private var measurements: FetchedResults<CellTweak>
    
    init(alsCells: FetchRequest<CellALS>, measurements: FetchRequest<CellTweak>) {
        self._alsCells = alsCells
        self._measurements = measurements
    }
    
    var body: some View {
        if SingleCellMap.hasAnyLocation(alsCells, measurements) {
            SingleCellMap(alsCells: alsCells, tweakCells: measurements)
                .frame(height: 200)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
    }
    
}

private struct CellDetailsCell: View {
    
    let cell: Cell
    let techFormatter: CellTechnologyFormatter
    
    init(cell: Cell) {
        self.cell = cell
        self.techFormatter = CellTechnologyFormatter.from(technology: cell.technology)
    }
    
    var body: some View {
        let (countryName, networkName) = OperatorDefinitions.shared.translate(country: cell.country, network: cell.network)
        
        Group {
            Section(header: Text("Cell Identification")) {
                CellDetailsRow("Technology", cell.technology ?? "Unknown")
                if let countryName = countryName {
                    CellDetailsRow("Country", countryName)
                }
                if let networkName = networkName {
                    CellDetailsRow("Network", networkName)
                }
                CellDetailsRow(techFormatter.country(), cell.country)
                CellDetailsRow(techFormatter.network(), cell.network)
                CellDetailsRow(techFormatter.area(), cell.area)
                CellDetailsRow(techFormatter.cell(), cell.cell)
            }
            
            if let measurement = cell as? CellTweak, let alsCell = measurement.appleDatabase {
                CellDetailsALSInfo(alsCell: alsCell, techFormatter: techFormatter)
            } else if let alsCell = cell as? CellALS {
                CellDetailsALSInfo(alsCell: alsCell, techFormatter: techFormatter)
            }
        }
    }
    
}

private struct CellDetailsALSInfo: View {
    
    let alsCell: CellALS
    let techFormatter: CellTechnologyFormatter
    
    var body: some View {
        Section(header: Text("ALS Information")) {
            if let importedDate = alsCell.imported {
                CellDetailsRow("Fetched", mediumDateTimeFormatter.string(from: importedDate))
            }
            if let alsLocation = alsCell.location {
                CellDetailsRow("Reach", "\(alsLocation.reach)m")
                CellDetailsRow("Location Score", "\(alsLocation.score)")
            }
            CellDetailsRow(techFormatter.frequency(), alsCell.frequency)
        }
    }
    
}

private struct TweakCellDetailsMeasurementCount: View {
    
    @FetchRequest private var alsCells: FetchedResults<CellALS>
    @FetchRequest private var measurements: FetchedResults<CellTweak>
    
    init(alsCells: FetchRequest<CellALS>, measurements: FetchRequest<CellTweak>) {
        self._alsCells = alsCells
        self._measurements = measurements
    }
    
    var body: some View {
        let count = GroupedMeasurements.countByStatus(measurements: measurements)
        
        Section(header: Text("Measurements")) {
            // We query the measurements in descending order, so that's we have to replace last with first and so on
            if let lastMeasurement = measurements.last, let firstCollected = lastMeasurement.collected {
                CellDetailsRow("First", mediumDateTimeFormatter.string(from: firstCollected))
            }
            if let firstMeasurement = measurements.first, let lastCollected = firstMeasurement.collected {
                CellDetailsRow("Last", mediumDateTimeFormatter.string(from: lastCollected))
            }
            CellDetailsRow("Pending", count.pending)
            CellDetailsRow("Suspicious", count.untrusted)
            CellDetailsRow("Anomalous", count.suspicious)
            CellDetailsRow("Trusted", count.trusted)
            NavigationLink {
                TweakCellMeasurementList(measurements: measurements)
            } label: {
                Text("Show Details")
            }
            .disabled(measurements.count == 0)
        }
    
    }
}

private struct TweakCellMeasurementList: View {
    
    let measurements: FetchedResults<CellTweak>
    
    var body: some View {
        List {
            ForEach(groupByDay(), id: \.key) { (day, dayMeasurements) in
                Section(header: Text(mediumDateFormatter.string(from: day))) {
                    ForEach(dayMeasurements, id: \CellTweak.id) { measurement in
                        TweakCellMeasurementNavLink(measurement: measurement)
                    }
                }
            }
        }
        .navigationTitle("Measurements")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
    }
    
    private func groupByDay() -> [(key: Date, value: [CellTweak])] {
        return Dictionary(grouping: measurements) { Calendar.current.startOfDay(for: $0.collected ?? Date()) }
            .sorted(by: {$0.key > $1.key})
    }
    
}

private struct TweakCellMeasurementNavLink: View {
    
    let measurement: CellTweak
    
    var body: some View {
        NavigationLink {
            // TODO: Update view
            // TweakCellMeasurementView(measurement: measurement)
            Text("TODO")
        } label: {
            HStack {
                if let collectedDate = measurement.collected {
                    Text("\(mediumTimeFormatter.string(from: collectedDate))")
                } else {
                    Text("No Date")
                }
                Spacer()
                Text("\(measurement.score)")
                    .foregroundColor(.gray)
            }
        }
    }
    
}

struct CellDetailsView_Previews: PreviewProvider {
    
    static var previews: some View {
        let (alsCell, measurements) = prepareDB()
        
        NavigationView {
            CellDetailsView(
                cell: measurements.first!,
                start: measurements.min(by: { $0.collected! < $1.collected! })!.collected!,
                end: measurements.max(by: { $0.collected! < $1.collected! })?.collected
            )
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .previewDisplayName("Tweak Measurement")
        
        NavigationView {
            CellDetailsView(
                cell: alsCell
            )
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .previewDisplayName("ALS Cell")
        
    }
    
    private static func prepareDB() -> (CellALS, [CellTweak]) {
        let context = PersistenceController.preview.container.viewContext
        let alsCell = PersistencePreview.alsCell(context: context)
        let tweakCells = [
            PersistencePreview.tweakCell(context: context, from: alsCell),
            PersistencePreview.tweakCell(context: context, from: alsCell),
            PersistencePreview.tweakCell(context: context, from: alsCell),
            PersistencePreview.tweakCell(context: context, from: alsCell)
        ]
        
        do {
            try context.save()
            PersistenceController.preview.fetchPersistentHistory()
        } catch {
            print("Something went wrong while preparing the preview")
        }
        
        return (alsCell, tweakCells)
    }
}
