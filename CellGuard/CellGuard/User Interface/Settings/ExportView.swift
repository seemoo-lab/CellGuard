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
    @State private var shareURL: URLIdentifiable? = nil
    @State private var showFailAlert: Bool = false
    @State private var failReason: String? = nil
    
    @State private var exportProgressUserCells: Float = 0
    @State private var exportProgressALSCells: Float = 0
    @State private var exportProgressLocations: Float = 0
    @State private var exportProgressPackets: Float = 0
    
    var body: some View {
        List {
            Section(header: Text("Datasets"), footer: Text("Be aware that every category includes highly personal information. Only share this data with persons you trust.")) {
                ProgressToggle("Connected Cells", isOn: $doExportCells, processing: $isExportInProgress, progress: $exportProgressUserCells)
                ProgressToggle("Cell Cache", isOn: $doExportALSCache, processing: $isExportInProgress, progress: $exportProgressALSCells)
                ProgressToggle("Locations", isOn: $doExportLocations, processing: $isExportInProgress, progress: $exportProgressLocations)
                ProgressToggle("Packets", isOn: $doExportPackets, processing: $isExportInProgress, progress: $exportProgressPackets)
            }
            Section(header: Text("Actions")) {
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
    
    func export() {
        isExportInProgress = true
        
        let exportCategories = [
            PersistenceCategory.connectedCells: doExportCells,
            PersistenceCategory.alsCells: doExportALSCache,
            PersistenceCategory.locations: doExportLocations,
            PersistenceCategory.packets: doExportPackets,
        ].filter { $0.value }.map { $0.key }
        
        exportProgressUserCells = -1
        exportProgressALSCells = -1
        exportProgressLocations = -1
        exportProgressPackets = -1
        
        PersistenceCSVExporter.exportInBackground(categories: exportCategories) { category, currentProgress, totalProgress in
            let progress = Float(currentProgress) / Float(totalProgress)
            switch (category) {
            case .connectedCells: exportProgressUserCells = progress
            case .alsCells: exportProgressALSCells = progress
            case .locations: exportProgressLocations = progress
            case .packets: exportProgressPackets = progress
            case .info: break
            }
        } completion: { result in
            exportProgressUserCells = -1
            exportProgressALSCells = -1
            exportProgressLocations = -1
            exportProgressPackets = -1
            
            do {
                self.shareURL = URLIdentifiable(url: try result.get())
            } catch {
                failReason = error.localizedDescription
                showFailAlert = true
            }
            
            isExportInProgress = false
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
        NavigationView {
            ExportView()
        }
    }
}
