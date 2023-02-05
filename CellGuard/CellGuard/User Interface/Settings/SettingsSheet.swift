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

struct SettingsSheet: View {
    
    let close: (SettingsCloseReason) -> ()
    
    init(close: @escaping (SettingsCloseReason) -> Void) {
        self.close = close
    }
    
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
    
    @State private var showAlert: AlertIdentifiable? = nil
    @State private var shareURL: URLIdentfiable? = nil
    @State private var isExportInProgress = false
    
    var body: some View {
        NavigationView {
            // TODO: Download other databases databases
            List {
                Section(header: Text("Permissions")) {
                    Toggle("Local Network", isOn: isPermissionLocalNetwork)
                        // The permission can't be revoked once granted
                        .disabled(isPermissionLocalNetwork.wrappedValue)
                    Toggle("Location (Always)", isOn: isPermissionAlwaysLocation)
                    Toggle("Notifications", isOn: isPermissionNotifications)
                }
                
                Section(header: Text("Location")) {
                    Toggle("Precise Background Updates", isOn: $locationManager.preciseInBackground)
                }
                
                Section(header: Text("Cell Databases")) {
                    Text("Apple Location Service")
                    /* Button {
                        self.showAlertNotImplemented()
                    } label: {
                        Text("OpenCellid Database")
                    }
                    
                    Button {
                        self.showAlertNotImplemented()
                    } label: {
                        Text("Mozilla Location Service")
                    } */
                }
                
                Section(header: Text("Collected Data")) {
                    HStack {
                        Button {
                            isExportInProgress = true
                            PersistenceExporter.exportInBackground { result in
                                isExportInProgress = false
                                do {
                                    self.shareURL = URLIdentfiable(url: try result.get())
                                } catch {
                                    // TODO: Show error
                                }
                            }
                        } label: {
                            Text("Export Data")
                        }
                        .disabled(isExportInProgress)
                        
                        if (isExportInProgress) {
                            Spacer()
                            ProgressView()
                        }
                    }
                    
                    Button {
                        self.showAlert = AlertIdentifiable(id: "confirm-delete", alert: Alert(
                            title: Text("Delete Database"),
                            message: Text("Delete all the app's data?"),
                            primaryButton: .cancel(),
                            secondaryButton: .destructive(Text("Delete")) {
                                // TODO: Handle error
                                close(.delete)
                                _ = PersistenceController.shared.deleteAllData()
                                UserDefaults.standard.setValue(false, forKey: UserDefaultsKeys.introductionShown.rawValue)
                            }
                        ))
                    } label: {
                        Text("Delete Data")
                            .foregroundColor(.red)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem() {
                    Button {
                        close(.done)
                    } label: {
                        Text("Done")
                            .bold()
                    }
                }
            }
            .sheet(item: $shareURL) { url in
                ActivityViewController(activityItems: [url.url])
            }
            .alert(item: $showAlert) { $0.alert }
        }
    }
    
    private func openAppSettings() {
        if let appSettings = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(appSettings) {
            UIApplication.shared.open(appSettings)
        }
    }
    
    private func showAlertNotImplemented() {
        self.showAlert = AlertIdentifiable(id: "not-yet-implemented", alert: Alert(
            title: Text("Not Yet Implemented"),
            message: Text("This feature is not yet implemented"),
            dismissButton: .default(Text("OK"))
        ))
    }
}

struct SettingsSheet_Previews: PreviewProvider {
    static var previews: some View {
        SettingsSheet { _ in
            // doing nothing
        }
        .environmentObject(LocationDataManager.shared)
        .environmentObject(LocalNetworkAuthorization(checkNow: true))
        .environmentObject(CGNotificationManager.shared)
    }
}
