//
//  RiskInfoView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 13.05.24.
//

import SwiftUI

struct RiskInfoView: View {
    
    let risk: RiskLevel
    @State private var showStudyView: Bool = false
    @AppStorage(UserDefaultsKeys.study.rawValue) var studyParticipationTimestamp: Double = 0
    @Environment(\.colorScheme) private var colorScheme
    
    

    
    // Shows explanations of the app's function and the user's risk (based on the risk level).
    // Be aware that the terms (of risk levels & cell categories) displayed to the user and used in the code differ.
    // See RiskIndicatorCard.swift for more information.
    var body: some View {
        NavigationView{
            ScrollView {
                
                Text(risk.header() + " Risk")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding()
                    .multilineTextAlignment(.center)
                
                Text(risk.verboseDescription())
                    .foregroundColor(.gray)
                    .padding()
                    .multilineTextAlignment(.center)
                
                
                NavigationLink {
                    
                    let calendar = Calendar.current
                    let subTwoWeeksFromCurrentDate = calendar.date(byAdding: .weekOfYear, value: -2, to: Date()) ?? Date()

                    // Medium risk -> show anomalous cells (weird comparision due to header...)
                    if risk.header() == RiskLevel.Medium(cause: RiskMediumCause.Permissions).header() {
                        CellListView(settings: CellListFilterSettings(status: .anomalous, timeFrame: PacketFilterTimeFrame.past, date: subTwoWeeksFromCurrentDate, showTwoWeeks: true))
                    }
                    // High risk -> show suspicious cells
                    else if risk.header() == RiskLevel.High(cellCount: 1).header() {
                        CellListView(settings: CellListFilterSettings(status: .suspicious, timeFrame: PacketFilterTimeFrame.past, date: subTwoWeeksFromCurrentDate, showTwoWeeks: true))
                    }
                    // Otherwise show all cells
                    else {
                        CellListView(settings: CellListFilterSettings(timeFrame: PacketFilterTimeFrame.past, date: subTwoWeeksFromCurrentDate, showTwoWeeks: true))
                    }
                } label: {
                    VStack {
                        HStack() {
                            Text("Show Cells")
                                .font(.title2)
                                .bold()
                            Spacer()
                            Image(systemName: "chevron.right.circle.fill")
                                .imageScale(.large)
                            
                        }
                        HStack {
                            Text("Show all \((risk == RiskLevel.Unknown || risk == RiskLevel.Low || risk == RiskLevel.LowMonitor) ? "" : "abnormal ")cells with \(risk.header().lowercased()) risk.")
                                .multilineTextAlignment(.leading)
                                .padding()
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                            .foregroundColor(risk.color(dark: colorScheme == .dark))
                            .shadow(color: .black.opacity(0.2), radius: 8)
                    )
                    .foregroundColor(.white)
                    .padding()
                }
            
                
                
                Text("CellGuard analyzes the information on your iPhone's baseband chip to validate the network cells it connects to. Furthermore, it compares cell information to the Apple Location Service (ALS) database to detect newly installed base stations. As of now, CellGuard implements the following detection metrics to assign a score of up to 100 points, with higher ratings reflecting trustworthy cells:")
                    .foregroundColor(.gray)
                    .padding()
                    .multilineTextAlignment(.center)
                
                Text("""
                • Failed Authentication (30)
                • Signal Strength (20)
                • Bandwidth (2)
                • Existence of cell in ALS database (20)
                • Distance between ALS and user location (20)
                • Comparison of cell info with ALS (8)
                """)
                .foregroundColor(.gray)
                .padding()
                .multilineTextAlignment(.leading)
                
                
                Image(systemName: "pencil.and.list.clipboard")
                    .foregroundColor(.blue)
                    .font(Font.custom("SF Pro", fixedSize: 120))
                    .frame(maxWidth: 40, alignment: .center)
                    .padding()
                
                if studyParticipationTimestamp == 0 {
                    Text("The CellGuard team is working on improving these metrics and uncovering fake base station abuse. Please join our study to contribute and report suspicious cells!")
                        .foregroundColor(.gray)
                        .padding()
                        .multilineTextAlignment(.center)
                    
                    NavigationLink(isActive: $showStudyView) {
                        UserStudyView(close: {}, returnToPreviousView: true)
                    } label: {
                        LargeButton(title: "Join Study", backgroundColor: .blue) {
                            showStudyView = true
                        }
                    }
                } else {
                    Text("Thank you for contributing to the CellGuard study. Your input will help us improve our metrics and uncover fake base station abuse.")
                        .foregroundColor(.gray)
                        .padding()
                        .multilineTextAlignment(.center)
                }
                    
                
                

                
                // Some more ideas for this view: https://dev.seemoo.tu-darmstadt.de/apple/cell-guard/-/issues/66
                // Maybe you could also use a SwiftUI List to display the information, be creative :)
                
                // TODO: Add a button linking to the RiskInfoCellListView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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
