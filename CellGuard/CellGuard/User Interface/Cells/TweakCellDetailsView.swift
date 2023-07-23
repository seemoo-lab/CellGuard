//
//  TweakCellDetailsView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 21.07.23.
//

import SwiftUI

struct TweakCellDetailsView: View {
    
    let firstMeasurement: TweakCell
    let start: Date
    let end: Date?
    
    @State private var showAll: Bool = false
    
    var body: some View {
        let (alsCellsRequest, measurementsRequest) = fetchRequests()
        
        List {
            TweakCellDetailsMap(alsCells: alsCellsRequest, measurements: measurementsRequest)
            TweakCellDetailsCell(someMeasurement: firstMeasurement)
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
        .navigationTitle("\(firstMeasurement.technology ?? "Unknown") Cell")
    }
    
    private func fetchRequests() -> (FetchRequest<ALSCell>, FetchRequest<TweakCell>) {
        let alsCellsRequest = FetchRequest<ALSCell>(
            sortDescriptors: [NSSortDescriptor(keyPath: \ALSCell.imported, ascending: false)],
            predicate: PersistenceController.shared.sameCellPredicate(cell: firstMeasurement),
            animation: .default
        )
        
        var measurementPredicates = [PersistenceController.shared.sameCellPredicate(cell: firstMeasurement)]
        if !showAll {
            measurementPredicates.append(NSPredicate(format: "collected >= %@", start as NSDate))
            if let end = end {
                measurementPredicates.append(NSPredicate(format: "collected <= %@", end as NSDate))
            }
        }
        let measurementsRequest = FetchRequest<TweakCell>(
            sortDescriptors: [NSSortDescriptor(keyPath: \TweakCell.collected, ascending: false)],
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: measurementPredicates),
            animation: .default
        )
        
        return (alsCellsRequest, measurementsRequest)
    }
    
}

private struct TweakCellDetailsMap: View {
    
    @FetchRequest private var alsCells: FetchedResults<ALSCell>
    @FetchRequest private var measurements: FetchedResults<TweakCell>
    
    init(alsCells: FetchRequest<ALSCell>, measurements: FetchRequest<TweakCell>) {
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

private struct TweakCellDetailsCell: View {
    
    let someMeasurement: TweakCell
    let techFormatter: CellTechnologyFormatter
    
    init(someMeasurement: TweakCell) {
        self.someMeasurement = someMeasurement
        self.techFormatter = CellTechnologyFormatter.from(technology: someMeasurement.technology)
    }
    
    var body: some View {
        let (countryName, networkName) = OperatorDefinitions.shared.translate(country: someMeasurement.country, network: someMeasurement.network)
        
        Group {
            Section(header: Text("Cell Identification")) {
                CellDetailsRow("Technology", someMeasurement.technology ?? "Unknown")
                if let countryName = countryName {
                    CellDetailsRow("Country", countryName)
                }
                if let networkName = networkName {
                    CellDetailsRow("Network", networkName)
                }
                CellDetailsRow(techFormatter.country(), someMeasurement.country)
                CellDetailsRow(techFormatter.network(), someMeasurement.network)
                CellDetailsRow(techFormatter.area(), someMeasurement.area)
                CellDetailsRow(techFormatter.cell(), someMeasurement.cell)
            }
            
            if let alsCell = someMeasurement.verification {
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
    }
    
}

private struct TweakCellDetailsMeasurementCount: View {
    
    @FetchRequest private var alsCells: FetchedResults<ALSCell>
    @FetchRequest private var measurements: FetchedResults<TweakCell>
    
    init(alsCells: FetchRequest<ALSCell>, measurements: FetchRequest<TweakCell>) {
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
            CellDetailsRow("Untrusted", count.untrusted)
            CellDetailsRow("Suspicious", count.suspicious)
            CellDetailsRow("Trusted", count.trusted)
            NavigationLink {
                TweakCellMeasurementList(measurements: measurements)
            } label: {
                Text("Show Details")
            }
        }
    
    }
}

private struct TweakCellMeasurementList: View {
    
    let measurements: FetchedResults<TweakCell>
    
    var body: some View {
        List {
            ForEach(groupByDay(), id: \.key) { (day, dayMeasurements) in
                Section(header: Text(mediumDateFormatter.string(from: day))) {
                    ForEach(dayMeasurements, id: \TweakCell.id) { measurement in
                        TweakCellMeasurementNavLink(measurement: measurement)
                    }
                }
            }
        }
        .navigationTitle("Measurements")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
    }
    
    private func groupByDay() -> [(key: Date, value: [TweakCell])] {
        return Dictionary(grouping: measurements) { Calendar.current.startOfDay(for: $0.collected ?? Date()) }
            .sorted(by: {$0.key > $1.key})
    }
    
}

private struct TweakCellMeasurementNavLink: View {
    
    let measurement: TweakCell
    
    var body: some View {
        NavigationLink {
            TweakCellMeasurementView(measurement: measurement)
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

struct TweakCellDetailsView_Previews: PreviewProvider {
    
    static var previews: some View {
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
            
            return AnyView(NavigationView {
                TweakCellDetailsView(
                    firstMeasurement: tweakCells.first!,
                    start: tweakCells.min(by: { $0.collected! < $1.collected! })!.collected!,
                    end: tweakCells.max(by: { $0.collected! < $1.collected! })?.collected
                )
            }.environment(\.managedObjectContext, context))
        } catch {
            return AnyView(Text("Error"))
        }
        
    }
}
