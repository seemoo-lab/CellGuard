//
//  ExportSheet.swift
//  CellGuard
//
//  Created by Lukas Arnold on 08.06.23.
//

import SwiftUI
import NavigationBackport

struct ExportView: View {
    @State private var doExportCells = true
    @State private var doExportALSCache = true
    @State private var doExportLocations = true
    @State private var doExportPackets = true
    @State private var doExportConnectivityEvents = true

    @State private var isExportInProgress = false
    @State private var shareURL: URLIdentifiable?
    @State private var showFailAlert: Bool = false
    @State private var failReason: String?

    @State private var exportProgressUserCells: Float = 0
    @State private var exportProgressALSCells: Float = 0
    @State private var exportProgressLocations: Float = 0
    @State private var exportProgressPackets: Float = 0
    @State private var exportProgressConnectivityEvents: Float = 0

    @AppStorage(UserDefaultsKeys.lastExportDate.rawValue)
    var lastExportDate: Double = -1.0

    var body: some View {
        List {
            Section(header: Text("Datasets"), footer: Text("Be aware that every category includes highly personal information. Only share this data with persons you trust.")) {
                ProgressToggle("Connected Cells", isOn: $doExportCells, processing: $isExportInProgress, progress: $exportProgressUserCells)
                ProgressToggle("Cell Cache", isOn: $doExportALSCache, processing: $isExportInProgress, progress: $exportProgressALSCells)
                ProgressToggle("Locations", isOn: $doExportLocations, processing: $isExportInProgress, progress: $exportProgressLocations)
                ProgressToggle("Packets", isOn: $doExportPackets, processing: $isExportInProgress, progress: $exportProgressPackets)
                ProgressToggle("Connectivity Events", isOn: $doExportConnectivityEvents, processing: $isExportInProgress, progress: $exportProgressConnectivityEvents)
            }
            Section(header: Text("Actions"), footer: Text(exportDateDescription())) {
                Button(action: export) {
                    HStack {
                        Text("Export")
                        Spacer()
                        if isExportInProgress {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                .disabled(!doExportCells && !doExportALSCache && !doExportLocations && !doExportPackets)
            }
        }
        .disabled(isExportInProgress)
        .listStyle(.insetGrouped)
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareURL) { url in
            ActivityViewController(activityItems: [url.url])
        }
        .alert(isPresented: $showFailAlert) {
            Alert(
                title: Text("Export Failed"),
                message: Text("Failed to export the selected datasets: \(failReason ?? "Unknown")")
            )
        }
    }

    func exportDateDescription() -> String {
        let prefix = "Last export: "
        if lastExportDate < 0 {
            return "\(prefix)Never"
        } else {
            let date = Date(timeIntervalSince1970: lastExportDate)
            return "\(prefix)\(mediumDateTimeFormatter.string(for: date)!)"
        }
    }

    func export() {
        isExportInProgress = true

        let exportCategories = [
            PersistenceCategory.connectedCells: doExportCells,
            PersistenceCategory.alsCells: doExportALSCache,
            PersistenceCategory.locations: doExportLocations,
            PersistenceCategory.packets: doExportPackets,
            PersistenceCategory.connectivityEvents: doExportConnectivityEvents
        ].filter { $0.value }.map { $0.key }

        exportProgressUserCells = -1
        exportProgressALSCells = -1
        exportProgressLocations = -1
        exportProgressPackets = -1
        exportProgressConnectivityEvents = -1

        PersistenceCSVExporter.exportInBackground(categories: exportCategories) { category, currentProgress, totalProgress in
            let progress = Float(currentProgress) / Float(totalProgress)
            switch category {
            case .connectedCells: exportProgressUserCells = progress
            case .alsCells: exportProgressALSCells = progress
            case .locations: exportProgressLocations = progress
            case .packets: exportProgressPackets = progress
            case .connectivityEvents: exportProgressConnectivityEvents = progress
            case .sysdiagnoses: break
            case .info: break
            }
        } completion: { result in
            exportProgressUserCells = -1
            exportProgressALSCells = -1
            exportProgressLocations = -1
            exportProgressPackets = -1
            exportProgressConnectivityEvents = -1

            do {
                self.shareURL = URLIdentifiable(url: try result.get())
            } catch {
                failReason = error.localizedDescription
                showFailAlert = true
            }

            isExportInProgress = false
            UserDefaults.standard.setValue(Date().timeIntervalSince1970, forKey: UserDefaultsKeys.lastExportDate.rawValue)
        }
    }
}

private struct ProgressToggle: View {

    let text: String
    @Binding var isOn: Bool
    @Binding var processing: Bool
    @Binding var progress: Float

    init(_ text: String, isOn: Binding<Bool>, processing: Binding<Bool>, progress: Binding<Float>) {
        self.text = text
        self._isOn = isOn
        self._processing = processing
        self._progress = progress
    }

    var body: some View {
        if processing {
            HStack {
                Text(text)
                Spacer()
                if progress >= 0 {
                    CircularProgressView(progress: $progress)
                        .frame(width: 20, height: 20)
                }
            }
            .foregroundColor(.gray)
        } else {
            Toggle(text, isOn: $isOn)
        }
    }
}

struct ExportView_Previews: PreviewProvider {
    static var previews: some View {
        NBNavigationStack {
            ExportView()
        }
    }
}
