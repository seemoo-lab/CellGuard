//
//  SettingsSheet.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.01.23.
//

import SwiftUI

private struct AlertIdentifiable: Identifiable {
    let id: String
    let alert: Alert
}

enum SettingsCloseReason {
    case done
    case delete
}

struct SettingsView: View {
    
    @AppStorage(UserDefaultsKeys.showTrackingMarker.rawValue) var showTrackingMarker: Bool = false
    @AppStorage(UserDefaultsKeys.appMode.rawValue) var appMode: DataCollectionMode = .none
    @AppStorage(UserDefaultsKeys.highVolumeSpeedup.rawValue) var highVolumeSpeedup: Bool = true
    
    @EnvironmentObject var locationManager: LocationDataManager
    @EnvironmentObject var notificationManager: CGNotificationManager
    
    private var isPermissionNotifications: Binding<Bool> { Binding(
        get: { notificationManager.authorizationStatus == .authorized },
        set: { value in
            if value {
                notificationManager.requestAuthorization() { result in
                    if !result {
                        openAppSettings()
                        // TODO: Update auth status once the app regains focus from settings
                    }
                }
            } else {
                openAppSettings()
            }
        }
    )}
    
    private var isPermissionAlwaysLocation: Binding<Bool> { Binding(
        get: { locationManager.authorizationStatus == .authorizedAlways },
        set: { value in
            if value && locationManager.authorizationStatus == .notDetermined {
                locationManager.requestAuthorization() { result in
                    if !result {
                        openAppSettings()
                    }
                }
            } else {
                openAppSettings()
            }
        }
    )}

    var body: some View {
        List {
            // TODO: Should we completely remove the automatic mode from the TestFlight / App Store version?
            Section(
                header: Text("Data Collection"),
                footer: Text(
                    "The data collection mode determines if and how CellGuard collects data. " +
                    "The automatic mode is not available on most devices. " +
                    "The manual mode allows you to share system diagnoses with the app to import data. " +
                    "If disabled, CellGuard does not collect locations and only allows you to import previously exported datasets."
                )
            ) {
                Picker("Mode", selection: $appMode) {
                    ForEach(DataCollectionMode.allCases) { Text($0.description) }
                }
            }
            
            Section(header: Text("Baseband Profile"), footer: Text("CellGuard only can extract data from sysdiagnoses which are created with an active baseband debug profile. The profile expires after 21 days.")) {
                Link(destination: URL(string: "https://developer.apple.com/bug-reporting/profiles-and-logs/?platform=ios&name=baseband")!, label: {
                    KeyValueListRow(key: "Download Profile") {
                        Image(systemName: "link")
                    }
                })
                // TODO: Add expected date of expiry & allow the user to manually set the date
                // TODO: Add toggle to notify user notifications before the profile's expiry
            }
            
            Section(header: Text("HighVolume Log Speedup"), footer: Text("Only scan certain log files from sysdiagnoses to speed up their import. Will be automatically disabled if not applicable for your system.")) {
                Toggle("Enable Speedup", isOn: $highVolumeSpeedup)
            }
            
            Section(header: Text("Permissions")) {
                Toggle("Location (Always)", isOn: isPermissionAlwaysLocation)
                Toggle("Notifications", isOn: isPermissionNotifications)
            }
            
            // TODO: Should we remove this?
            Section(header: Text("Location")) {
                Toggle("Show Tracking Indicator", isOn: $showTrackingMarker)
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
            
            Section(header: Text("About CellGuard")) {
                NavigationLink {
                    AcknowledgementView()
                } label: {
                    Text("Acknowledgements")
                }
                
                KeyValueListRow(key: "Version", value: versionBuild)

                Link(destination: URL(string: "https://cellguard.seemoo.de")!) {
                    KeyValueListRow(key: "Website") {
                        Image(systemName: "link")
                    }
                }
                
                Link(destination: URL(string: "https://cellguard.seemoo.de/docs/privacy-policy/")!) {
                    KeyValueListRow(key: "Privacy Policy") {
                        Image(systemName: "link")
                    }
                }
                
                // TODO: Create GitHub project
                Link(destination: URL(string: "http://github.com/seemoo-lab/CellGuard")!) {
                    KeyValueListRow(key: "Report Issues") {
                        Image(systemName: "link")
                    }
                }
            }
            
            Section(header: Text("Developers"), footer: Text("CellGuard is a research project by the Secure Mobile Networking Lab at TU Darmstadt (SEEMOO) and the Cybersecurity - Mobile & Wireless group at the Hasso Plattner Institute (HPI).")) {
                Link(destination: URL(string: "https://lukasarnold.de")!) {
                    KeyValueListRow(key: "Lukas Arnold", value: "SEEMOO")
                }
                Link(destination: URL(string: "https://hpi.de/classen/home.html")!) {
                    KeyValueListRow(key: "Jiska Classen", value: "HPI")
                }
                KeyValueListRow(key: "Linus Laurenz", value: "HPI")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("Settings"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    var versionBuild: String {
        // https://stackoverflow.com/a/28153897
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "???"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String  ?? "???"
        
        return "\(version) (\(build))"
    }
    
    private func openAppSettings() {
        if let appSettings = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(appSettings) {
            UIApplication.shared.open(appSettings)
        }
    }
}

struct SettingsSheet_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
        }
        .environmentObject(LocationDataManager.shared)
        .environmentObject(CGNotificationManager.shared)
    }
}
