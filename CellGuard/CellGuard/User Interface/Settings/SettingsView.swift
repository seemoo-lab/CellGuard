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
    
    @EnvironmentObject var locationManager: LocationDataManager
    @EnvironmentObject var networkAuthorization: LocalNetworkAuthorization
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
    
    private var isPermissionLocalNetwork: Binding<Bool> { Binding(
        get: { networkAuthorization.lastResult ?? false },
        set: { value in
            if value {
                networkAuthorization.requestAuthorization() { result in
                    if !result {
                        openAppSettings()
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
            Section(header: Text("Permissions")) {
                Toggle("Local Network", isOn: isPermissionLocalNetwork)
                // The permission can't be revoked once granted
                    .disabled(isPermissionLocalNetwork.wrappedValue)
                Toggle("Location (Always)", isOn: isPermissionAlwaysLocation)
                Toggle("Notifications", isOn: isPermissionNotifications)
            }
            
            Section(header: Text("Cell Verification")) {
                Picker("Approach", selection: $locationManager.proximityDetection) {
                    Text("Database Validation").tag(false)
                    Text("Proximity Detection").tag(true)
                }
                if locationManager.proximityDetection {
                    Toggle("Show Tracking Indicator", isOn: $showTrackingMarker)
                }
            }
            
            Section(header: Text("Local Database")) {
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
                KeyValueListRow(key: "Version", value: versionBuild)
                // TODO: Open mail with the correct address on click
                KeyValueListRow(key: "Developer", value: "Lukas Arnold")
                KeyValueListRow(key: "Supervisor", value: "Jiska Classen")
                Link(destination: URL(string: "https://www.seemoo.tu-darmstadt.de")!) {
                    KeyValueListRow(key: "Institution", value: "SEEMOO @ TU Darmstadt")
                }
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
        .environmentObject(LocalNetworkAuthorization(checkNow: true))
        .environmentObject(CGNotificationManager.shared)
    }
}
