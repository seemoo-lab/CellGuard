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
    
    @State private var doCompressFile = true
    
    @State private var isExportInProgress = false
    @State private var shareURL: URLIdentifiable? = nil
    @State private var showFailAlert: Bool = false
    @State private var failReason: String? = nil
    
    var body: some View {
        List {
            Section(header: Text("Included Datasets"), footer: Text("Be aware that every category includes highly personal information. Only share this data with persons you trust.")) {
                Toggle("Connected Cells", isOn: $doExportCells)
                Toggle("Cell Cache", isOn: $doExportALSCache)
                Toggle("Locations", isOn: $doExportLocations)
                Toggle("Packets", isOn: $doExportPackets)
            }
            Section(header: Text("File"), footer: Text("Enable compression to decrease the file's size.")) {
                Toggle("Compression", isOn: $doCompressFile)
            }
        }
        .disabled(isExportInProgress)
        .listStyle(.insetGrouped)
        .navigationTitle(Text("Data"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Prevent the "< Settings" button from disappearing on iOS 14
            // See: https://stackoverflow.com/a/72432154
            ToolbarItem(placement: .navigationBarLeading) {
                Text("")
            }
            
            ToolbarItem(placement: ToolbarItemPlacement.navigationBarTrailing) {
                if (isExportInProgress) {
                    ProgressView()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    export()
                } label: {
                    Text("Export")
                }
                .disabled(!doExportCells && !doExportALSCache && !doExportLocations && !doExportPackets || isExportInProgress)
            }
        }
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
        
        PersistenceExporter.exportInBackground(categories: exportCategories, compress: doCompressFile) { result in
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
