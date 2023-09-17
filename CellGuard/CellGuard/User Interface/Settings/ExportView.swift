//
//  ExportSheet.swift
//  CellGuard
//
//  Created by Lukas Arnold on 08.06.23.
//

import SwiftUI

struct ExportView: View {
    @State private var doExportCells = true
    @State private var doExportALSCache = true
    @State private var doExportLocations = true
    @State private var doExportPackets = true
    
    @State private var isExportInProgress = false
    @State private var exportProgress: Float = 0.0
    @State private var shareURL: URLIdentifiable? = nil
    @State private var showFailAlert: Bool = false
    @State private var failReason: String? = nil
    
    var body: some View {
        List {
            Section(header: Text("Datasets"), footer: Text("Be aware that every category includes highly personal information. Only share this data with persons you trust.")) {
                Toggle("Connected Cells", isOn: $doExportCells)
                Toggle("Cell Cache", isOn: $doExportALSCache)
                Toggle("Locations", isOn: $doExportLocations)
                Toggle("Packets", isOn: $doExportPackets)
            }
            Section(header: Text("Actions")) {
                Button(action: export) {
                    HStack {
                        Text("Export")
                        Spacer()
                        if isExportInProgress {
                            CircularProgressView(progress: $exportProgress)
                                .frame(width: 20, height: 20)
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
    
    func export() {
        isExportInProgress = true
        
        let exportCategories = [
            PersistenceCategory.connectedCells: doExportCells,
            PersistenceCategory.alsCells: doExportALSCache,
            PersistenceCategory.locations: doExportLocations,
            PersistenceCategory.packets: doExportPackets,
        ].filter { $0.value }.map { $0.key }
        
        PersistenceCSVExporter.exportInBackground(categories: exportCategories) { currentProgress, totalProgress in
            exportProgress = Float(currentProgress) / Float(totalProgress)
        } completion: { result in
            isExportInProgress = false
            do {
                self.shareURL = URLIdentifiable(url: try result.get())
            } catch {
                failReason = error.localizedDescription
                showFailAlert = true
            }
        }
    }
}

struct ExportView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ExportView()
        }
    }
}
