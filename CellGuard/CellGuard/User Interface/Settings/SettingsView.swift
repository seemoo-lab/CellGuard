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
    
    @AppStorage(UserDefaultsKeys.introductionShown.rawValue) var introductionShown: Bool = true
    @AppStorage(UserDefaultsKeys.appMode.rawValue) var appMode: DataCollectionMode = .none
    @AppStorage(UserDefaultsKeys.study.rawValue) var studyParticipationTimestamp: Double = 0
    
    @State private var showQuitStudyAlert = false

    var body: some View {
        List {
            PermissionSection()
            
            // TODO: Add notifications sections
            // - Toggle for suspicious cell notifications
            // - Toggle for anomalous cell notifications
            // - Toggle for close notifications
            // - (TODO) Toggle for regular sysdiagnose record reminders
            // - (TODO) Toggle for regular sysdiagnose import reminders
            // - (TODO) Toggle for profile expiry notification
            
            // Only show the baseband profile setting in the manual mode
            if appMode == .manual {
                // TODO: Add expected date of expiry (read from sysdiagnose) & allow the user to manually set the date
                Section(header: Text("Baseband Profile"), footer: Text("Keep the baseband debug profile on your device up-to-date to collect logs for CellGuard.")) {
                    NavigationLink {
                        DebugProfileDetailedView()
                    } label: {
                        Text("Install Profile")
                    }
                }
            }
            
            Section(header: Text("Study"), footer: Text("Join our study to improve CellGuard.")) {
                if studyParticipationTimestamp == 0 {
                    NavigationLink {
                        // TODO: Why does
                        UserStudyView(returnToPreviousView: true)
                    } label: {
                        Text("Participate")
                    }
                } else {
                    Button {
                        showQuitStudyAlert = true
                    } label: {
                        Text("End Participation")
                    }
                }
                
                NavigationLink {
                    StudyContributionsView()
                } label: {
                    Text("Your Contributions")
                }
            }
            
            Section(header: Text("Introduction"), footer: Text("View the introduction to learn how CellGuard works.")) {
                Button("Restart Intro") {
                    introductionShown = false
                }
            }
            
            Section {
                NavigationLink {
                    InformationContactView()
                } label: {
                    Text("Information & Contact")
                }
                NavigationLink {
                    AdvancedSettingsView()
                } label: {
                    Text("Advanced Settings")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showQuitStudyAlert) {
            Alert(
                title: Text("End Participation?"),
                message: Text("You will no longer contribute data to the CellGuard study."),
                primaryButton: .destructive(Text("End"), action: {
                    studyParticipationTimestamp = 0
                    showQuitStudyAlert = false
                }),
                secondaryButton: .default(Text("Continue"), action: {
                    showQuitStudyAlert = false
                })
            )
        }
    }
}

private struct PermissionSection: View {
    
    @ObservedObject private var locationManager = LocationDataManager.shared
    @ObservedObject var notificationManager = CGNotificationManager.shared
    
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
        Section(header: Text("Permissions"), footer: Text("Check that CellGuard has all required permission to function correctly.")) {
            Toggle("Location (Always)", isOn: isPermissionAlwaysLocation)
            Toggle("Notifications", isOn: isPermissionNotifications)
        }
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
