//
//  AdvancedSettingsView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.06.24.
//

import SwiftUI

struct AdvancedSettingsView: View {
    
    @AppStorage(UserDefaultsKeys.showTrackingMarker.rawValue) var showTrackingMarker: Bool = false
    @AppStorage(UserDefaultsKeys.appMode.rawValue) var appMode: DataCollectionMode = .none
    @AppStorage(UserDefaultsKeys.highVolumeSpeedup.rawValue) var highVolumeSpeedup: Bool = true
    
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
        List {
            Section(
                header: Text("Data Collection"),
                footer: Text(dataCollectionFooter)
            ) {
                Picker("Mode", selection: $appMode) {
                    ForEach(DataCollectionMode.allCases) { Text($0.description) }
                }
            }
            
            Section(header: Text("HighVolume Log Speedup"), footer: Text("Only scan certain log files from sysdiagnoses to speed up their import. Will be automatically disabled if not applicable for your system.")) {
                Toggle("Enable Speedup", isOn: $highVolumeSpeedup)
            }
            
            Section(header: Text("Location"), footer: Text("Show iOS' background indicator to quickly access CellGuard.")) {
                Toggle("Background Indicator", isOn: $showTrackingMarker)
            }
            
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
    }
    
}
