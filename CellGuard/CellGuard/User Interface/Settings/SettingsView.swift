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
    @AppStorage(UserDefaultsKeys.appMode.rawValue) var appMode: AppModes = AppModes.jailbroken
    
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
            Section(header: Text("App Features"), footer: Text("The selected mode determines the actions of the app executed in the background.")) {
                Picker("Mode", selection: $appMode) {
                    ForEach(AppModes.allCases) { Text($0.description) }
                }
            }
            
            Section(header: Text("Permissions")) {
                Toggle("Location (Always)", isOn: isPermissionAlwaysLocation)
                Toggle("Notifications", isOn: isPermissionNotifications)
            }
            
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
