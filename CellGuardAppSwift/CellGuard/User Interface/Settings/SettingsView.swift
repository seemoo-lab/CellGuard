//
//  SettingsSheet.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.01.23.
//

import SwiftUI
import NavigationBackport

private struct AlertIdentifiable: Identifiable {
    let id: String
    let alert: Alert
}

enum SettingsCloseReason {
    case done
    case delete
}

struct SettingsView: View {

    var body: some View {
        List {
            PermissionSection()

            NotificationsSection()

            BasebandProfileSection()

            StudySection()

            #if JAILBREAK
            BackgroundTasksSection()
            #endif

            IntroductionSection()

            Section {
                ListNavigationLink(value: SummaryNavigationPath.informationContact) {
                    Text("Information & Contact")
                }
                ListNavigationLink(value: SummaryNavigationPath.settingsAdvanced) {
                    Text("Advanced Settings")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("Settings"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PermissionSection: View {

    @ObservedObject private var locationManager = LocationDataManagerPublished.shared
    @ObservedObject var notificationManager = CGNotificationManager.shared

    private var isPermissionNotifications: Binding<Bool> { Binding(
        get: { notificationManager.authorizationStatus == .authorized },
        set: { value in
            if value {
                notificationManager.requestAuthorization { result in
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
                LocationDataManager.shared.requestAuthorization { result in
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

private struct NotificationsSection: View {
    @ObservedObject var notificationManager = CGNotificationManager.shared
    @AppStorage(UserDefaultsKeys.suspiciousCellNotification.rawValue) var suspiciousCell: Bool = true
    @AppStorage(UserDefaultsKeys.anomalousCellNotification.rawValue) var anomalousCell: Bool = true
    @AppStorage(UserDefaultsKeys.keepCGRunningNotification.rawValue) var keepCGRunning: Bool = true
    @AppStorage(UserDefaultsKeys.profileExpiryNotification.rawValue) var profileExpiry: Bool = true
    @AppStorage(UserDefaultsKeys.newSysdiagnoseNotification.rawValue) var newSysdiagnose: Bool = true

    var body: some View {
        if notificationManager.authorizationStatus == .authorized {
            Section(header: Text("Notifications"), footer: Text("Check which notifications you want to receive.")) {
                Toggle("Suspicious Cell", isOn: $suspiciousCell)
                Toggle("Anomalous Cell", isOn: $anomalousCell)
                Toggle("Profile Expiry", isOn: Binding(get: {
                    profileExpiry
                }, set: { newValue in
                    profileExpiry = newValue
                    // Refresh the profile data if the user enables this setting
                    if newValue {
                        scanForProfile()
                    }
                }))
                Toggle("Sysdiagnose Status", isOn: $newSysdiagnose)
                Toggle("Exit Warning", isOn: $keepCGRunning)
            }
        }
    }

    private func scanForProfile() {
        Task.detached {
            let task = ProfileTask()
            await task.run()
        }
    }
}

private struct BasebandProfileSection: View {
    @StateObject private var profileData = ProfileData.shared

    @AppStorage(UserDefaultsKeys.profileExpiryNotification.rawValue) var profileExpiry: Bool = true
    @AppStorage(UserDefaultsKeys.appMode.rawValue) var appMode: DataCollectionMode = .none

    var body: some View {
        if appMode == .manual {
            Section(header: Text("Baseband Profile"), footer: Text(footer)) {
                ListNavigationLink(value: SummaryNavigationPath.debugProfile) {
                    Text("Install Profile")
                }

                // Only show the data if the setting is enabled as otherwise the scan may be outdated.
                if profileExpiry {
                    if let installData = profileData.installDate {
                        KeyValueListRow(key: "Installed", value: mediumDateTimeFormatter.string(for: installData) ?? "n/a")
                    }
                    if let removalDate = profileData.removalDate {
                        KeyValueListRow(key: "Expires") {
                            Text(mediumDateTimeFormatter.string(for: removalDate) ?? "n/a")
                                .foregroundColor(profileData.installState == .expiringSoon ? .orange : .gray)
                        }
                    }
                }
            }
        }
    }

    var footer: String {
        let text = "Keep the baseband debug profile on your device up-to-date to collect logs for CellGuard."

        if profileExpiry {
            return text
        } else {
            return text + " Enable profile expiry notifications to see the profile's status."
        }
    }
}

private struct StudySection: View {

    @AppStorage(UserDefaultsKeys.study.rawValue) var studyParticipationTimestamp: Double = 0
    @State private var showQuitStudyAlert = false

    var body: some View {
        Section(header: Text("Study"), footer: Text("Join our study to improve CellGuard.")) {
            if studyParticipationTimestamp == 0 {
                ListNavigationLink(value: SummaryNavigationPath.userStudy) {
                    Text("Participate")
                }
            } else {
                Button {
                    showQuitStudyAlert = true
                } label: {
                    Text("End Participation")
                }
            }

            ListNavigationLink(value: SummaryNavigationPath.userStudyContributions) {
                Text("Your Contributions")
            }
        }
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

private struct BackgroundTasksSection: View {

    @AppStorage(UserDefaultsKeys.updateCheck.rawValue) private var isUpdateChecks: Bool = false

    var body: some View {
        Section(header: Text("Background Tasks"), footer: Text("If enabled, CellGuard regularly queries our backend server to check for updates.")) {
            Toggle("Update Checks", isOn: Binding(get: {
                return isUpdateChecks
            }, set: { value in
                isUpdateChecks = value

                // Perform an update check if the user enabled the setting
                if value {
                    Task.detached(priority: .background) {
                        await UpdateCheckTask().run()
                    }
                }
            }))
        }
    }
}

private struct IntroductionSection: View {
    @AppStorage(UserDefaultsKeys.introductionShown.rawValue) var introductionShown: Bool = true

    var body: some View {
        Section(header: Text("Introduction"), footer: Text("View the introduction to learn how CellGuard works.")) {
            Button("Restart Intro") {
                introductionShown = false
            }
        }
    }
}

struct SettingsSheet_Previews: PreviewProvider {
    static var previews: some View {
        @State var cellFilterSettings = CellListFilterSettings()

        NBNavigationStack {
            SettingsView()
                .cgNavigationDestinations(.summaryTab)
                .cgNavigationDestinations(.cells)
                .cgNavigationDestinations(.operators)
                .cgNavigationDestinations(.packets)
        }
        .environmentObject(CGNotificationManager.shared)
        .environmentObject(cellFilterSettings)
    }
}
