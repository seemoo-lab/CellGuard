//
//  RiskIndicator.swift
//  CellGuard
//
//  Created by Lukas Arnold on 16.01.23.
//

import UIKit
import SwiftUI

enum RiskMediumCause: Equatable {
    case Permissions
    case TweakCells
    case TweakPackets
    case Location
    case Cells(cellCount: Int)
    case CantCompute
    case DiskSpace
    case LowPowerMode
    
    func text() -> String {
        let ftDaysSuffix = UserDefaults.standard.dataCollectionMode() != .none ? " in the last 14 days" : ""
        
        switch (self) {
        case .Permissions:
            return "Ensure you granted all required permissions!"
        case .TweakCells:
            return "Waiting for cell data from the CapturePacketTweak"
        case .TweakPackets:
            return "Waiting for data from the CapturePacketTweak"
        case .Location:
            return "Ensure you granted always on location permissions!"
        case let .Cells(cellCount):
            return "Detected a minor anomaly for \(cellCount) \(cellCount == 1 ? "cell" : "cells")\(ftDaysSuffix)."
        case .CantCompute:
            return "Unable to determine your risk."
        case .DiskSpace:
            return "There's less than 1GB of disk space available for opportunistic usage. This might impact your iPhone's ability to collect logs!"
        case .LowPowerMode:
            return "Disable Low-Power-Mode to collect logs!"
        }
    }
}

enum RiskLevel: Equatable {
    case Unknown
    case Low
    case LowMonitor
    case Medium(cause: RiskMediumCause)
    case High(cellCount: Int)
    
    func header() -> String {
        switch (self) {
        case .Unknown: return "Unknown"
        case .Low: return "Low"
        case .LowMonitor: return "Low"
        case .Medium: return "Low"
        case .High: return "Increased"
        }
    }
    
    // as shown in mini card
    func description() -> String {
        let ftDaysSuffix = UserDefaults.standard.dataCollectionMode() != .none ? " collected in the last 14 days" : ""
        
        switch (self) {
        case .Unknown:
            return "Collecting and processing data."
        case .Low:
            return "Verified all cells\(ftDaysSuffix)."
        case .LowMonitor:
            return "Monitoring the connected cell and verified the remaining cells."
        case let .Medium(cause):
            return cause.text()
        case let .High(cellCount):
            return "Detected \(cellCount) suspicious \(cellCount == 1 ? "cell" : "cells")\(ftDaysSuffix)."
        }
    }
    
    // as shown in risk explanation
    func verboseDescription() -> String {
        @AppStorage(UserDefaultsKeys.study.rawValue) var studyParticipationTimestamp: Double = 0
        let ftDaysSuffix = UserDefaults.standard.dataCollectionMode() != .none ? " collected in the last 14 days" : ""
        
        let explanationSuffix = "In most cases, cellular anomalies can be explained by non-malicious network settings: The ALS scores trigger when your network provider legitimately sets up new cells, authentication fails when your iPhone connects to third-party cells to enable emergency calls during lousy network coverage, and bandwidth decreases for high-user-density environments.\n\nWe recommend taking a detailed look into the scores and manually comparing the detection result with the actual circumstances of the anomaly detection."
        
        let studySuffix = studyParticipationTimestamp == 0 ? "The CellGuard team is studying fake base station behavior and countermeasures! As a next step in the fight against fake base stations, we recommend that you participate in our study." : "By participating in the study, you did everything possible to uncover fake base station abuse. The CellGuard team is actively analyzing and studying fake base station behavior and countermeasures!"
        
        switch (self) {
        case .Unknown:
            return "CellGuard is still collecting and processing data, your current risk status is unknown."
        case .Low:
            return "CellGuard verified all cells\(ftDaysSuffix). No anomalies were detected."
        case .LowMonitor:
            return "CellGuard is monitoring the connected cell and verified the remaining cells. No anomalies were detected."
        case let .Medium(cause):
            switch cause {
            case .Cells(cellCount: _):
                return "\(cause.text())\n\n\(explanationSuffix)"
            default:
                return cause.text()
            }
        case let .High(cellCount):
            return "Detected \(cellCount) suspicious \(cellCount == 1 ? "cell" : "cells")\(ftDaysSuffix).\n\n\(explanationSuffix)\n\n\(studySuffix)"
        }
    }
    
    func color(dark: Bool) -> Color {
        switch (self) {
        case .Unknown: return dark ? Color(UIColor.systemGray6) : .gray
        case .Low: return dark ? Color(.green * 0.6 + .black * 0.4) : .green
        case .LowMonitor: return dark ? Color(.green * 0.6 + .black * 0.4) : .green
        case .Medium: return dark ? Color(.blue * 0.4 + .black * 0.7): .blue
        case .High: return dark ? Color(.red * 0.2 + .yellow * 0.1 + .black * 0.4) : .orange
        }
    }
    
    
}

extension RiskLevel: Comparable {
    func level() -> Int {
        switch self {
        case .Low:
            return 0
        case .LowMonitor:
            return 0
        case .Unknown:
            return 1
        case .Medium(cause: _):
            return 2
        case .High(cellCount: _):
            return 3
        }
    }
    
    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        return lhs.level() < rhs.level()
    }
}

extension RiskLevel {
    
    func isCausedByCells() -> Bool {
        switch (self) {
        case let .Medium(cause: mediumCause):
            switch (mediumCause) {
            case .Cells(cellCount: _):
                return true
            default:
                return false
            }
        case .High(cellCount: _):
            return true
        default:
            return false
        }
    }
    
}

struct RiskIndicatorCard: View {
    
    let risk: RiskLevel
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationLink {
            RiskInfoView(risk: risk)
        } label: {
            VStack {
                HStack() {
                    Text("\(risk.header()) Risk")
                        .font(.title2)
                        .bold()
                    Spacer()
                    if risk == .Unknown {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "chevron.right.circle.fill")
                            .imageScale(.large)
                    }
                }
                HStack {
                    Text(risk.description())
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
    }
}

struct RiskIndicator_Previews: PreviewProvider {
    static var previews: some View {
        RiskIndicatorCard(risk: .Unknown)
            .previewDisplayName("Unknown")
        RiskIndicatorCard(risk: .Low)
            .previewDisplayName("Low")
        RiskIndicatorCard(risk: .LowMonitor)
            .previewDisplayName("Low (Monitor)")
        RiskIndicatorCard(risk: .Medium(cause: .Permissions))
            .previewDisplayName("Medium (Permissions)")
        RiskIndicatorCard(risk: .Medium(cause: .Cells(cellCount: 3)))
            .previewDisplayName("Medium (Cells)")
        RiskIndicatorCard(risk: .High(cellCount: 3))
            .previewDisplayName("High")
        RiskIndicatorCard(risk: .Unknown)
            .previewDisplayName("Unknown (dark)")
            .preferredColorScheme(.dark)
        RiskIndicatorCard(risk: .Low)
            .previewDisplayName("Low (dark)")
            .preferredColorScheme(.dark)
        RiskIndicatorCard(risk: .LowMonitor)
            .previewDisplayName("Low (Monitor) (dark)")
            .preferredColorScheme(.dark)
        RiskIndicatorCard(risk: .Medium(cause: .Permissions))
            .previewDisplayName("Medium (Permissions) (dark)")
            .preferredColorScheme(.dark)
        RiskIndicatorCard(risk: .Medium(cause: .Cells(cellCount: 3)))
            .previewDisplayName("Medium (Cells) (dark)")
            .preferredColorScheme(.dark)
        RiskIndicatorCard(risk: .High(cellCount: 3))
            .previewDisplayName("High (dark)")
            .preferredColorScheme(.dark)
    }
}
