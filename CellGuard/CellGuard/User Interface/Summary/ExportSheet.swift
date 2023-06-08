//
//  ExportSheet.swift
//  CellGuard
//
//  Created by Lukas Arnold on 08.06.23.
//

import SwiftUI

struct ExportSheet: View {
    let close: () -> Void
    
    @State private var doExportCells = true
    @State private var doExportALSCache = true
    @State private var doExportLocations = true
    @State private var doExportPackets = true
    
    @State private var isExportInProgress = false
    @State private var shareURL: URLIdentfiable? = nil
    @State private var showFailAlert: Bool = false
    @State private var failReason: String? = nil
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Included Datasets"), footer: Text("Be aware that every category includes highly personal information. Only share this data with persons you trust.")) {
                    Toggle("Connected Cells", isOn: $doExportCells)
                    Toggle("Cell Cache", isOn: $doExportALSCache)
                    Toggle("Locations", isOn: $doExportLocations)
                    Toggle("Packets", isOn: $doExportPackets)
                }
                .disabled(isExportInProgress)
            }
            .navigationTitle(Text("Data"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        close()
                    } label: {
                        Text("Close")
                    }
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
                        Text("Share")
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
    }
    
    func export() {
        isExportInProgress = true
        // TODO: Pass properties & Include new categories
        PersistenceExporter.exportInBackground { result in
            isExportInProgress = false
            do {
                self.shareURL = URLIdentfiable(url: try result.get())
            } catch {
                failReason = error.localizedDescription
                showFailAlert = true
            }
        }
    }
}

struct ExportSheet_Previews: PreviewProvider {
    static var previews: some View {
        ExportSheet() {
            // doing nothing
        }
    }
}
