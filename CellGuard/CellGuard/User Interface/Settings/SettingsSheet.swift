//
//  SettingsSheet.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.01.23.
//

import SwiftUI

struct AlertIdentifiable: Identifiable {
    let id: String
    let alert: Alert
}

struct SettingsSheet: View {
    
    let tapDone: () -> ()
    
    init(tapDone: @escaping () -> Void) {
        self.tapDone = tapDone
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
        // TODO: Sometimes crashes here
        // Thread 1: Fatal error: No ObservableObject of type LocalNetworkAuthorization found. A View.environmentObject(_:) for LocalNetworkAuthorization may be missing as an ancestor of this view.
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
    
    var body: some View {
        NavigationView {
            // TODO: Permissions
            // TODO: Download databases
            // TODO: Delete all data
            List {
                Section(header: Text("Permissions")) {
                    // TODO: Open settings app on disable
                    Toggle("Local Network", isOn: isPermissionLocalNetwork)
                        // The permission can't be revoked once granted
                        .disabled(isPermissionLocalNetwork.wrappedValue)
                    Toggle("Location (Always)", isOn: isPermissionAlwaysLocation)
                    Toggle("Notifications", isOn: isPermissionNotifications)
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
                    Button {
                        self.showAlertNotImplemented()
                    } label: {
                        Text("Export Data")
                    }
                    
                    Button {
                        self.showAlert = AlertIdentifiable(id: "confirm-delete", alert: Alert(
                            title: Text("Confirm Deletion"),
                            message: Text("Delete all recorded data?"),
                            primaryButton: .cancel(),
                            secondaryButton: .destructive(Text("Continue"))
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
                    Button(action: self.tapDone) {
                        Text("Done").bold()
                    }
                }
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
        self.showAlert = AlertIdentifiable(id: "todo", alert: Alert(
            title: Text("Not Yet Implemented"),
            message: Text("This feature is not yet implemented"),
            dismissButton: .default(Text("OK"))
        ))
    }
}

struct SettingsSheet_Previews: PreviewProvider {
    static var previews: some View {
        SettingsSheet {
            // doing nothing
        }
        .environmentObject(LocationDataManager.shared)
        .environmentObject(LocalNetworkAuthorization(checkNow: true))
        .environmentObject(CGNotificationManager.shared)
    }
}
