//
//  SummaryNavigationPath.swift
//  CellGuard
//
//  Created by Lukas Arnold on 18.06.25.
//

import NavigationBackport
import Foundation
import SwiftUI

enum SummaryNavigationPath: NBScreen {

    case cellList
    case cellListFilter
    case connectivity
    case connectivityFilter
    case dataSummary
    case cellLaboratory
    case operatorLookup

    case settings
    case settingsAdvanced
    case informationContact
    case acknowledgements
    case acknowledgementsSwift
    case acknowledgementsRust
    case dataImport
    case dataExport
    case dataDelete

    case userStudy
    case userStudyContributions
    case userStudyScoresWeekly

    case sysdiagInstructions
    case sysdiagOpenSettings
    case debugProfile

    @MainActor
    @ViewBuilder
    static func navigate(_ path: SummaryNavigationPath) -> some View {
        if path == .cellList {
            CellListView()
        } else if path == .cellListFilter {
            CellListFilterView()
        } else if path == .connectivity {
            ConnectivityView()
        } else if path == .connectivityFilter {
            ConnectivityListFilterView()
        } else if path == .dataSummary {
            DataSummaryView()
        } else if path == .cellLaboratory {
            DebugAddCellView()
        } else if path == .operatorLookup {
            OperatorLookupView()
        } else if path == .settings {
            SettingsView()
        } else if path == .settingsAdvanced {
            AdvancedSettingsView()
        } else if path == .informationContact {
            InformationContactView()
        } else if path == .acknowledgements {
            AcknowledgementView()
        } else if path == .acknowledgementsSwift {
            SwiftAcknowledgementView()
        } else if path == .acknowledgementsRust {
            RustAcknowledgementView()
        } else if path == .dataImport {
            ImportView()
        } else if path == .dataExport {
            ExportView()
        } else if path == .dataDelete {
            DeleteView()
        } else if path == .userStudy {
            UserStudyView(titleMode: .automatic) { navigator in
                navigator.pop()
            }
        } else if path == .userStudyContributions {
            StudyContributionsView()
        } else if path == .userStudyScoresWeekly {
            StudyWeeklyScoresView()
        } else if path == .sysdiagInstructions {
            SysdiagInstructionsDetailedView()
        } else if path == .sysdiagOpenSettings {
            SysdiagOpenSettingsDetailedView()
        } else if path == .debugProfile {
            DebugProfileDetailedView()
        } else {
            Text("Missing navigation path: \(String(describing: path))")
        }
    }

    var id: SummaryNavigationPath {
        self
    }

}
