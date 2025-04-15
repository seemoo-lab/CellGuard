//
//  CellDetailsView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 21.07.23.
//

import CoreData
import SwiftUI

struct CellDetailsView: View {
    
    let cell: Cell
    let predicate: NSPredicate?
    
    @State private var showAll: Bool
    
    init(alsCell: CellALS) {
        self.cell = alsCell
        self.predicate = nil
        self._showAll = State(initialValue: true)
    }
    
    init(tweakCell: CellTweak, predicate: NSPredicate? = nil) {
        self.cell = tweakCell
        self.predicate = predicate
        self._showAll = State(initialValue: false)
    }
    
    var body: some View {
        let alsCellsRequest = alsFetchRequest()
        let measurementsRequest = tweakFetchRequest()
        
        List {
            TweakCellDetailsMap(alsCells: alsCellsRequest, verifyStates: measurementsRequest)
            CellDetailsCell(cell: cell, verifyStates: measurementsRequest)
            TweakCellDetailsMeasurementCount(alsCells: alsCellsRequest, verifyStates: measurementsRequest)
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
    
    private func alsFetchRequest() -> FetchRequest<CellALS> {
        return FetchRequest<CellALS>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CellALS.imported, ascending: false)],
            predicate: PersistenceController.shared.sameCellPredicate(cell: cell, mergeUMTS: true),
            animation: .default
        )
    }
    
    private func tweakFetchRequest() -> FetchRequest<VerificationState> {
        var predicates = [
            PersistenceController.shared.sameCellPredicate(cell: cell, mergeUMTS: false, prefix: "cell.")
        ]
        
        // Append custom predicates
        if !showAll, let predicate = predicate {
            predicates.append(predicate)
        }
        
        // Ensure the correct pipeline is used & the cell is not null
        predicates.append(NSPredicate(format: "pipeline == %@", Int(primaryVerificationPipeline.id) as NSNumber))
        predicates.append(NSPredicate(format: "cell != nil"))
        
        let request = VerificationState.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "cell.collected", ascending: false)]
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.relationshipKeyPathsForPrefetching = ["cell"]
        return FetchRequest(fetchRequest: request, animation: .default)
    }
    
}

private struct TweakCellDetailsMap: View {
    
    @FetchRequest private var alsCells: FetchedResults<CellALS>
    @FetchRequest private var verifyStates: FetchedResults<VerificationState>
    
    init(alsCells: FetchRequest<CellALS>, verifyStates: FetchRequest<VerificationState>) {
        self._alsCells = alsCells
        self._verifyStates = verifyStates
    }
    
    var body: some View {
        let tweakCells = verifyStates.compactMap { $0.cell }
        
        if SingleCellMap.hasAnyLocation(alsCells, tweakCells) {
            ExpandableMap {
                SingleCellMap(alsCells: alsCells, tweakCells: tweakCells)
            }
        }
    }
    
}

private struct CellDetailsCell: View {
    
    let cell: Cell
    let techFormatter: CellTechnologyFormatter
    
    @FetchRequest private var verifyStates: FetchedResults<VerificationState>

    init(cell: Cell, verifyStates: FetchRequest<VerificationState>) {
        self.cell = cell
        self.techFormatter = CellTechnologyFormatter.from(technology: cell.technology)
        self._verifyStates = verifyStates
    }
    
    var body: some View {
        let simSlotsSet = Set(verifyStates.compactMap { $0.cell?.simSlotID })
        let simSlots = simSlotsSet.map { "\($0)" }.sorted().joined(separator: ",")
        Group {
            CellCountryNetworkSection(country: cell.country, network: cell.network, techFormatter: techFormatter)
            Section(header: Text("Technology & Region")) {
                CellDetailsRow("Technology", cell.technology ?? "Unknown")
                CellDetailsRow("SIM Slot", simSlots)
                if let tweakCell = cell as? CellTweak,
                   tweakCell.supports5gNsa() {
                    CellDetailsRow("5G NSA", "Supported")
                }

                CellDetailsRow(techFormatter.area(), cell.area)
            }
            Section(header: Text("Cell & Tower")) {
                CellDetailsRow(techFormatter.cell(), cell.cell)
                CellDetailsIdentification(cell: cell)
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
    @FetchRequest private var verifyStates: FetchedResults<VerificationState>
    
    init(alsCells: FetchRequest<CellALS>, verifyStates: FetchRequest<VerificationState>) {
        self._alsCells = alsCells
        self._verifyStates = verifyStates
    }
    
    var body: some View {
        let count = countByStatus(verifyStates)
        
        Section(header: Text("Measurements")) {
            // We query the measurements in descending order, so that's we have to replace last with first and so on
            if let lastMeasurement = verifyStates.last?.cell, let firstCollected = lastMeasurement.collected {
                CellDetailsRow("First", mediumDateTimeFormatter.string(from: firstCollected))
            }
            if let firstMeasurement = verifyStates.first?.cell, let lastCollected = firstMeasurement.collected {
                CellDetailsRow("Last", mediumDateTimeFormatter.string(from: lastCollected))
            }
            CellDetailsRow("Pending", count.pending)
            CellDetailsRow("Suspicious", count.untrusted)
            CellDetailsRow("Anomalous", count.suspicious)
            CellDetailsRow("Trusted", count.trusted)
            NavigationLink {
                TweakCellMeasurementList(measurements: verifyStates.compactMap { $0.cell })
            } label: {
                Text("Show Details")
            }
            .disabled(verifyStates.count == 0)
        }
    
    }
    
    func countByStatus(_ verificationStates: any RandomAccessCollection<VerificationState>) -> (pending: Int, trusted: Int, suspicious: Int, untrusted: Int) {
        var pending = 0
        
        var untrusted = 0
        var suspicious = 0
        var trusted = 0
        
        for state in verificationStates {
            if state.finished {
                if state.score < primaryVerificationPipeline.pointsUntrusted {
                    untrusted += 1
                } else if state.score < primaryVerificationPipeline.pointsSuspicious {
                    suspicious += 1
                } else {
                    trusted += 1
                }
            } else {
                pending += 1
            }
        }
        
        return (pending, trusted, suspicious, untrusted)
    }

}

private struct TweakCellMeasurementList: View {
    
    @State private var pipelineId: Int16 = primaryVerificationPipeline.id
    let measurements: any RandomAccessCollection<CellTweak>
    
    var body: some View {
        List {
            ForEach(groupByDay(), id: \.key) { (day, dayMeasurements) in
                Section(header: Text(mediumDateFormatter.string(from: day))) {
                    ForEach(dayMeasurements, id: \CellTweak.id) { measurement in
                        TweakCellMeasurementNavLink(measurement: measurement, pipelineId: pipelineId)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Pipeline", selection: $pipelineId) {
                        ForEach(UserDefaults.standard.userEnabledVerificationPipelines(), id: \.id) {
                            Text($0.name)
                        }
                    }
                } label: {
                    Label("Pipeline", systemImage: "waveform.path.ecg")
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
    let pipelineId: Int16
    
    var body: some View {
        if let state = measurement.verifications?.compactMap({ $0 as? VerificationState }).first(where: { $0.pipeline == pipelineId }) {
            NavigationLink {
                VerificationStateView(verificationState: state)
            } label: {
                label(score: state.finished ? state.score : nil, study: measurement.study != nil)
            }
        } else {
            // Maybe we could also use the progress label here?
            labelUnknown()
        }
    }
    
    private func labelUnknown() -> some View {
        HStack {
            date
            Spacer()
            Image(systemName: "questionmark.diamond")
        }
    }
    
    private func label(score: Int16?, study: Bool) -> some View {
        HStack {
            date
            Spacer()
            if study {
                Image(systemName: "arrow.up.circle")
                    .foregroundColor(.gray)
            }
            if let score = score {
                Text("\(score)")
                    .foregroundColor(.gray)
            } else {
                ProgressView()
            }
        }
    }
    
    private var date: some View {
        if let collectedDate = measurement.collected {
            Text("\(mediumTimeFormatter.string(from: collectedDate))")
        } else {
            Text("No Date")
        }
    }
    
}

struct CellDetailsView_Previews: PreviewProvider {
    
    static var previews: some View {
        let (alsCell, measurements) = prepareDB()
        
        NavigationView {
            CellDetailsView(
                tweakCell: measurements.first!,
                predicate: NSPredicate(value: true)
            )
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .previewDisplayName("Tweak Measurement")
        
        NavigationView {
            CellDetailsView(
                alsCell: alsCell
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
