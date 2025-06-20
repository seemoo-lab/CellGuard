//
//  TweakCellMeasurementView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 21.07.23.
//

import SwiftUI
import CoreData
import NavigationBackport

struct VerificationStateView: View {

    var verificationState: VerificationState

    var body: some View {
        List {
            if let measurement = verificationState.cell,
               let verificationPipeline = activeVerificationPipelines.first(where: { $0.id == verificationState.pipeline }) {
                VerificationStateInternalView(verificationPipeline: verificationPipeline, verificationState: verificationState, measurement: measurement)
            } else {
                Text("No cell has been assigned to this verification state or the selected verification pipeline is missing.")
            }
        }
        .navigationTitle("Verification State")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
    }

}

private struct VerificationStateInternalView: View {

    let verificationPipeline: VerificationPipeline
    @ObservedObject var verificationState: VerificationState
    @ObservedObject var measurement: CellTweak

    var body: some View {
        let techFormatter = CellTechnologyFormatter.from(technology: measurement.technology)

        var currentStage: VerificationStage?
        if !verificationState.finished && verificationState.stage < verificationPipeline.stages.count {
            currentStage = verificationPipeline.stages[Int(verificationState.stage)]
        }

        let logs = verificationState.logs?
            .compactMap { $0 as? VerificationLog }
            .sorted { $0.stageNumber < $1.stageNumber }
        ?? []

        return Group {
            Section(header: Text("Date & Time")) {
                if let collectedDate = measurement.collected {
                    CellDetailsRow("Collected", fullMediumDateTimeFormatter.string(from: collectedDate))
                }
                if let importedDate = measurement.imported {
                    CellDetailsRow("Imported", fullMediumDateTimeFormatter.string(from: importedDate))
                }
            }

            Section(header: Text("Cell Properties")) {
                if let rat = measurement.technology {
                    CellDetailsRow("Generation", rat)
                }
                CellDetailsRow(techFormatter.frequency(), measurement.frequency)
                CellDetailsRow("Band", measurement.band)
                CellDetailsRow("Bandwidth", measurement.bandwidth)
                CellDetailsRow("Physical Cell ID", measurement.physicalCell)
                if measurement.technology == "LTE" {
                    CellDetailsRow("Deployment Type", measurement.deploymentType)
                }

                if let qmiPacket = measurement.packetQmi {
                    NBNavigationLink(value: NavObjectId(object: qmiPacket)) { PacketCell(packet: qmiPacket) }
                } else if let ariPacket = measurement.packetAri {
                    NBNavigationLink(value: NavObjectId(object: ariPacket)) { PacketCell(packet: ariPacket) }
                }
            }

            // TODO: Should we show the cell's identification (MNC, MCC, ...) which is shown two pages up?

            if let json = measurement.json, let jsonPretty = try? self.formatJSON(json: json) {
                Section(header: Text("iOS-Internal Data")) {
                    Text(jsonPretty)
                        .font(Font(UIFont.monospacedSystemFont(ofSize: UIFont.smallSystemFontSize, weight: .regular)))
                }
            }

            if verificationState.finished && verificationPipeline.id == primaryVerificationPipeline.id {
                VerificationStateStudyView(verificationPipeline: verificationPipeline, verificationState: verificationState, measurement: measurement)
            }

            Section(header: Text("Verification")) {
                CellDetailsRow("Status", verificationState.finished ? "Finished" : "In Progress")
                CellDetailsRow("Pipeline", verificationPipeline.name)
                CellDetailsRow("Stages", verificationPipeline.stages.count)
                CellDetailsRow("Points", "\(verificationState.score) / \(verificationPipeline.pointsMax)")
                if verificationState.finished {
                    if verificationState.score >= verificationPipeline.pointsSuspicious {
                        CellDetailsRow("Verdict", "Trusted", icon: "lock.shield")
                    } else if verificationState.score >= verificationPipeline.pointsUntrusted {
                        CellDetailsRow("Verdict", "Anomalous", icon: "shield")
                    } else {
                        CellDetailsRow("Verdict", "Suspicious", icon: "exclamationmark.shield")
                    }
                    Button {
                        let measurementId = measurement.objectID
                        Task(priority: .background) {
                            try? PersistenceController.shared.clearVerificationData(tweakCellID: measurementId)
                        }
                    } label: {
                        KeyValueListRow(key: "Clear Verification Data") {
                            Image(systemName: "trash")
                        }
                    }
                }
            }

            ForEach(logs, id: \.id) { logEntry in
                VerificationStateLogEntryView(logEntry: logEntry, stage: stageFor(logEntry: logEntry))
            }

            if let currentStage = currentStage {
                Section(header: Text("Stage: \(currentStage.name) (\(verificationState.stage))"), footer: Text(currentStage.description)) {
                    KeyValueListRow(key: "Status") {
                        ProgressView()
                    }
                    CellDetailsRow("Points", "\(currentStage.points)")
                    CellDetailsRow("Requires Packets", currentStage.waitForPackets ? "Yes" : "No")
                }
            }
        }
    }

    private func stageFor(logEntry: VerificationLog) -> VerificationStage? {
        // Since this verification log entry was recorded its respective verification pipeline could have been modified.
        // We try to find the current's states description in the most effective manner.

        // Check if the stage resides in the same position of the pipeline
        if let stage = verificationPipeline.stages[safe: Int(logEntry.stageNumber)],
            stage.id == logEntry.stageId {
            return stage
        }

        // Check if the stages resides anywhere in the pipeline
        if let stage = verificationPipeline.stages.first(where: { $0.id == logEntry.stageId }) {
            return stage
        }

        // The stage is missing from the pipeline
        return nil
    }

    private func formatJSON(json inputJSON: String?) throws -> String? {
        guard let inputJSON = inputJSON else {
            return nil
        }

        guard let inputData = inputJSON.data(using: .utf8) else {
            return nil
        }

        let parsedData = try JSONSerialization.jsonObject(with: inputData)
        let outputJSON = try JSONSerialization.data(withJSONObject: parsedData, options: .prettyPrinted)

        return String(data: outputJSON, encoding: .utf8)
    }
}

struct VerificationStateView_Previews: PreviewProvider {

    static var previews: some View {
        /*let viewContext = PersistenceController.preview.container.viewContext
        let cell = PersistencePreview.alsCell(context: viewContext)
        let tweakCell = PersistencePreview.tweakCell(context: viewContext, from: cell)
        tweakCell.appleDatabase = cell
        // TODO: JSON for tests
        tweakCell.json = """
[{"RSRP":0,"CellId":12941845,"BandInfo":1,"TAC":45711,"CellType":"CellTypeServing","SectorLat":0,"CellRadioAccessTechnology":"RadioAccessTechnologyLTE","SectorLong":0,"MCC":262,"PID":461,"MNC":2,"DeploymentType":1,"RSRQ":0,"Bandwidth":100,"UARFCN":100},{"timestamp":1672513186.351948}]
"""
        
        do {
            try viewContext.save()
        } catch {
            
        }
        
        PersistenceController.preview.fetchPersistentHistory()
        
        return VerificationStateView(verificationState: tweakCell)
            .environment(\.managedObjectContext, viewContext) */
        Text("TODO")
    }
}
