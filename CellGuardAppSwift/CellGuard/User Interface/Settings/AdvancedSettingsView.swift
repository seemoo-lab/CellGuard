//
//  AdvancedSettingsView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.06.24.
//

import OSLog
import SwiftUI

struct AdvancedSettingsView: View {

    var body: some View {
        List {
            DataCollectionSection()

            LogarchiveSection()

            LocationSection()

            #if LOCAL_BACKEND
            BackendSection()
            #endif

            PipelineSection()

            Section(header: Text("Local Database")) {
                NavigationLink {
                    ImportView()
                } label: {
                    Text("Import Data")
                }
                NavigationLink {
                    ExportView()
                } label: {
                    Text("Export Data")
                }
                NavigationLink {
                    DeleteView()
                } label: {
                    Text("Delete Data")
                }
            }
        }
        .navigationTitle("Advanced Settings")
        .listStyle(.insetGrouped)
    }

}

private struct DataCollectionSection: View {

    @AppStorage(UserDefaultsKeys.appMode.rawValue) var appMode: DataCollectionMode = .none

    private var dataCollectionFooter: String {
        var text = "The data collection mode determines if and how CellGuard collects data. "

        #if JAILBREAK
        text += "The automatic mode retrieves data from tweaks installed with a jailbreak on your device. "
        #endif

        text += "The manual mode allows you to share system diagnoses with the app to import data. "
        text += "If disabled, CellGuard does not collect locations and only allows you to import previously exported datasets."

        return text
    }

    var body: some View {
        Section(
            header: Text("Data Collection"),
            footer: Text(dataCollectionFooter)
        ) {
            Picker("Mode", selection: $appMode) {
                ForEach(DataCollectionMode.allCases) { Text($0.description) }
            }
        }

        if appMode == .automatic {
            TweakSection()
        }
    }

}

private struct TweakSection: View {

    @ObservedObject var clientState = CPTClientState.shared

    var body: some View {
        Section(header: Text("Capture Cells Tweak")) {
            KeyValueListRow(key: "Queried") {
                if let lastConnection = clientState.lastConnection {
                    Text(mediumDateTimeFormatter.string(from: lastConnection))
                } else {
                    Text("Never")
                }
            }
            if let hello = clientState.lastHello {
                KeyValueListRow(key: "Version", value: hello.version)
            } else {
                if clientState.lastConnection != nil {
                    KeyValueListRow(key: "Version", value: "<= 1.0.5")
                } else {
                    KeyValueListRow(key: "Version", value: "???")
                }
            }
        }
    }

}

private struct LogarchiveSection: View {

    @AppStorage(UserDefaultsKeys.logArchiveSpeedup.rawValue) var logArchiveSpeedup: Bool = true

    var body: some View {
        Section(header: Text("Logarchive Import Speedup"), footer: Text("Only scan certain log files from sysdiagnoses to speed up their import. Will be automatically disabled if not applicable for your system.")) {
            Toggle("Enable Speedup", isOn: $logArchiveSpeedup)
        }
    }
}

private struct LocationSection: View {

    @AppStorage(UserDefaultsKeys.showTrackingMarker.rawValue) var showTrackingMarker: Bool = false

    var body: some View {
        Section(header: Text("Location"), footer: Text("Show iOS' background indicator to quickly access CellGuard.")) {
            Toggle("Background Indicator", isOn: $showTrackingMarker)
        }
    }
}

private struct BackendSection: View {

    var body: some View {
        Section(header: Text("Backend"), footer: Text("\(CellGuardURLs.baseUrl.absoluteString)")) {
            Button {
                Task.detached(priority: .userInitiated) {
                    var calendar = Calendar(identifier: .gregorian)
                    calendar.timeZone = TimeZone(identifier: "UTC")!
                    let beginningOfWeek = calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: Date()).date!
                    try PersistenceController.shared.deleteStudyScore(of: beginningOfWeek)
                }
            } label: {
                Text("Clear Weekly Scores")
            }
        }
    }

}

private struct PipelineSection: View {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: PipelineSection.self)
    )

    var body: some View {
        Section(header: Text("Verification Pipelines"), footer: Text("Each verification pipeline checks your collected data for unique suspicious patterns. You cannot disable the primary pipeline.")) {
            ForEach(activeVerificationPipelines, id: \.id) { pipeline in
                let primary = pipeline.id == primaryVerificationPipeline.id

                Toggle("\(pipeline.name)\(primary ? " (Primary)" : "")", isOn: .init(get: {
                    primary ? true : UserDefaults.standard.userEnabledVerificationPipelineIds().contains(pipeline.id)
                }, set: { newVal in
                    // Get enabled pipelines
                    var enabledPipelines = UserDefaults.standard.userEnabledVerificationPipelineIds()

                    // Add or remove the pipeline in question
                    if newVal {
                        enabledPipelines.insert(pipeline.id)
                        Self.logger.info("User enabled pipeline \(pipeline.name) with id \(pipeline.id)")
                    } else {
                        if let index = enabledPipelines.firstIndex(of: pipeline.id) {
                            enabledPipelines.remove(at: index)
                            Self.logger.info("User disabled pipeline \(pipeline.name) with id \(pipeline.id)")
                        }
                    }

                    // Update user defaults with the new array (convert set to array beforehand)
                    UserDefaults.standard.setValue(enabledPipelines.sorted(), forKey: UserDefaultsKeys.activePipelines.rawValue)
                }))
                .disabled(primary)
            }
        }
    }
}
