//
//  RiskInfoView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 13.05.24.
//

import SwiftUI

struct RiskInfoView: View {
    
    let risk: RiskLevel
    @AppStorage(UserDefaultsKeys.study.rawValue) var studyParticipationTimestamp: Double = 0
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Shows explanations of the app's function and the user's risk (based on the risk level).
    // Be aware that the terms (of risk levels & cell categories) displayed to the user and used in the code differ.
    // See RiskIndicatorCard.swift for more information.
    var body: some View {
        List {
            Section(header: Text("Risk"), footer: Text(risk.verboseDescription())) {
                KeyValueListRow(key: "Your Risk") {
                    // Don't use dimmed dark mode colors for the font
                    Text(risk.header())
                        .foregroundColor(risk.color(dark: false))
                }
                
                if risk == .Unknown {
                    ProgressCounterView()
                }
            }
            
            // iOS 14 doesn't like it if a subview is open but the originating NavigationLink vanishes and removes "Back" button.
            // Thus, we have to implement a work around for iOS 14.
            let calendar = Calendar.current
            let subTwoWeeksFromCurrentDate = calendar.date(byAdding: .weekOfYear, value: -2, to: Date()) ?? Date()
            
            if #available(iOS 15, *) {
                if risk.isCausedByCells() {
                    Section(header: Text("Affected Cells")) {
                        // We don't link trusted cells as this list would be too large and cause performance issues (?)
                        
                        NavigationLink {
                            CellListView(settings: CellListFilterSettings(status: .anomalous, timeFrame: .pastDays, date: subTwoWeeksFromCurrentDate))
                        } label: {
                            Text(Image(systemName: "shield")) + Text(" Anomalous Cells")
                        }
                        
                        if risk >= .High(cellCount: 1) {
                            NavigationLink {
                                CellListView(settings: CellListFilterSettings(status: .suspicious, timeFrame: .pastDays, date: subTwoWeeksFromCurrentDate))
                            } label: {
                                Text(Image(systemName: "exclamationmark.shield")) + Text(" Suspicious Cells")
                            }
                        }
                    }
                }
            } else {
                Section(header: Text("Affected Cells")) {
                    // We don't link trusted cells as this list would be too large and cause performance issues (?)
                    
                    NavigationLink {
                        CellListView(settings: CellListFilterSettings(status: .anomalous, timeFrame: .pastDays, date: subTwoWeeksFromCurrentDate))
                    } label: {
                        Text(Image(systemName: "shield")) + Text(" Anomalous Cells")
                    }
                    .disabled(!risk.isCausedByCells())
                    
                    NavigationLink {
                        CellListView(settings: CellListFilterSettings(status: .suspicious, timeFrame: .pastDays, date: subTwoWeeksFromCurrentDate))
                    } label: {
                        Text(Image(systemName: "exclamationmark.shield")) + Text(" Suspicious Cells")
                    }.disabled(risk < .High(cellCount: 1))
                }
            }
            
            if studyParticipationTimestamp == 0 {
                Section(header: Text("Study"), footer: Text("The CellGuard team researches the abuse of fake base stations. Please join our study to contribute suspicious cells and help us to improve our methodology for uncovering them!")) {
                    NavigationLink {
                        UserStudyView(returnToPreviousView: true)
                    } label: {
                        if #available(iOS 17, *) {
                            Text(Image(systemName: "pencil.and.list.clipboard")) + Text(" Participate")
                        } else {
                            Text(Image(systemName: "doc.on.clipboard")) + Text(" Participate")
                        }
                    }
                    .foregroundColor(.blue)
                }
            } else {
                Section(header: Text("Study"), footer: Text("Thank you for contributing to the CellGuard study. Your input will help us improve our metrics and uncover fake base station abuse.")) {
                    NavigationLink {
                        StudyContributionsView()
                    } label: {
                        Text("Your Contributions")
                    }
                }
            }
            
            Section(header: Text("Methodology"), footer: Text("""
                CellGuard analyzes the information on your iPhone's baseband chip to validate the network cells it connects to. Furthermore, it compares cell information to the Apple Location Service (ALS) database to detect newly installed base stations.
                
                As of now, CellGuard implements the following detection metrics to assign a score of up to 100 points, with higher ratings reflecting trustworthy cells:
                • Failed Authentication (30)
                • Signal Strength (20)
                • Bandwidth (2)
                • Existence of Cell in ALS Database (20)
                • Distance between ALS and User Location (20)
                • Comparison of Cell Info with ALS (8)
                """)) {
                
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Risk Level")
        .listStyle(.insetGrouped)
    }
        
}

private struct ProgressCounterView: View {
    
    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "finished == NO and pipeline == %@", Int(primaryVerificationPipeline.id) as NSNumber)
    )
    private var unverifiedStates: FetchedResults<VerificationState>
    
    var body: some View {
        KeyValueListRow(key: "Verification Progress", value: "\(unverifiedStates.count)")
    }
    
}

struct RiskInfoView_Previews: PreviewProvider {
    static var previews: some View {
        RiskInfoView(risk: .Unknown)
            .previewDisplayName("Unknown")
        RiskInfoView(risk: .Low)
            .previewDisplayName("Low")
        RiskInfoView(risk: .LowMonitor)
            .previewDisplayName("Low (Monitor)")
        RiskInfoView(risk: .Medium(cause: .Permissions))
            .previewDisplayName("Medium (Permissions)")
        RiskInfoView(risk: .Medium(cause: .Cells(cellCount: 3)))
            .previewDisplayName("Medium (Cells)")
        RiskInfoView(risk: .High(cellCount: 3))
            .previewDisplayName("High")
    }
}
