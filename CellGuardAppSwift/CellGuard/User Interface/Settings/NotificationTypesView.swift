//
//  NotificationSettingsView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 13.05.26.
//

import SwiftUI

struct NotificationTypesView: View {
    var body: some View {
        List {
            NotificationsSection()
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("Notifications"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NotificationsSection: View {
    @ObservedObject var notificationManager = CGNotificationManager.shared
    @AppStorage(UserDefaultsKeys.suspiciousCellNotification.rawValue) var suspiciousCell: Bool = true
    @AppStorage(UserDefaultsKeys.anomalousCellNotification.rawValue) var anomalousCell: Bool = true
    @AppStorage(UserDefaultsKeys.keepCGRunningNotification.rawValue) var keepCGRunning: Bool = true
    @AppStorage(UserDefaultsKeys.profileExpiryNotification.rawValue) var profileExpiry: Bool = true
    @AppStorage(UserDefaultsKeys.newSysdiagnoseNotification.rawValue) var newSysdiagnose: Bool = true

    var body: some View {
        Section(header: Text("Types"), footer: Text("Configure which types of notifications you want to receive.")) {
            Toggle("Suspicious Cell", isOn: $suspiciousCell)
            Toggle("Anomalous Cell", isOn: $anomalousCell)
            Toggle("Profile Expiry", isOn: Binding(get: {
                profileExpiry
            }, set: { newValue in
                profileExpiry = newValue
                if newValue {
                    // Refresh the profile data if the user enables this setting
                    scanForProfile()
                } else {
                    // Cancel all pending profile expiry notifications if the user disables it
                    CGNotificationManager.shared.cancelProfileExpiryNotification()
                }
            }))
            Toggle("Sysdiagnose Status", isOn: $newSysdiagnose)
            Toggle("Exit Warning", isOn: $keepCGRunning)
        }
        .disabled(notificationManager.authorizationStatus != .authorized)
    }

    var footer: String {
        let general = "Configure which types of notifications you want to receive."
        let disabled = "No notifications will be delivered as you did not grant the iOS permission."
        if notificationManager.authorizationStatus != .authorized {
            return general + " " + disabled
        } else {
            return general
        }
    }

    private func scanForProfile() {
        Task.detached {
            let task = ProfileTask()
            await task.run()
        }
    }
}

#Preview {
    NotificationTypesView()
}
