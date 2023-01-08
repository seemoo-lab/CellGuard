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
    
    @State private var isPermissionLocalNetwork = false
    @State private var isPermissionAlwaysLocation = false
    @State private var isPermissionNotifications = false
    
    @State private var showAlert: AlertIdentifiable? = nil
    
    var body: some View {
        NavigationView {
            // TODO: Permissions
            // TODO: Download databases
            // TODO: Delete all data
            List {
                Section(header: Text("Permissions")) {
                    Toggle("Local Network", isOn: $isPermissionLocalNetwork)
                        .onChange(of: isPermissionLocalNetwork) { value in
                            
                        }
                    Toggle("Location (Always)", isOn: $isPermissionAlwaysLocation)
                        .onChange(of: isPermissionAlwaysLocation) { value in
                            
                        }
                    Toggle("Notifications", isOn: $isPermissionNotifications)
                        .onChange(of: isPermissionNotifications) { value in
                            
                        }
                }
                
                Section(header: Text("Cell Databases")) {
                    Text("Apple Location Service")
                    Button {
                        self.showAlertNotImplemented()
                    } label: {
                        Text("OpenCellid Database")
                    }
                    
                    Button {
                        self.showAlertNotImplemented()
                    } label: {
                        Text("Mozilla Location Service")
                    }
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
    }
}
