//
//  RiskIndicator.swift
//  CellGuard
//
//  Created by Lukas Arnold on 16.01.23.
//

import UIKit
import SwiftUI
import NavigationBackport

enum RiskMediumCause: Equatable, Hashable {
    case permissions
    case tweakCells
    case tweakPackets
    case location
    case cells(cellCount: Int)
    case cantCompute
    case diskSpace
    case lowPowerMode

    func text() -> String {
        let ftDaysSuffix = UserDefaults.standard.dataCollectionMode() != .none ? " in the last 14 days" : ""

        switch self {
        case .permissions:
            return "Ensure you granted all required permissions!"
        case .tweakCells:
            return "Waiting for cell data from the CapturePacketTweak"
        case .tweakPackets:
            return "Waiting for data from the CapturePacketTweak"
        case .location:
            return "Ensure you granted always on location permissions!"
        case let .cells(cellCount):
            return "Detected a minor anomaly for \(cellCount) \(cellCount == 1 ? "cell" : "cells")\(ftDaysSuffix)."
        case .cantCompute:
            return "Unable to determine your risk."
        case .diskSpace:
            return "There's less than 1GB of disk space available for opportunistic usage. This might impact your iPhone's ability to collect logs!"
        case .lowPowerMode:
            return "Disable Low-Power-Mode to collect logs!"
        }
    }
}

enum RiskLevel: Equatable, Hashable {
    case unknown
    case low
    case lowMonitor
    case medium(cause: RiskMediumCause)
    case high(cellCount: Int)

    func header() -> String {
        switch self {
        case .unknown: return "Unknown"
        case .low: return "Low"
        case .lowMonitor: return "Low"
        case .medium: return "Low"
        case .high: return "Increased"
        }
    }

    // as shown in mini card
    func description() -> String {
        let ftDaysSuffix = UserDefaults.standard.dataCollectionMode() != .none ? " collected in the last 14 days" : ""

        switch self {
        case .unknown:
            return "Collecting and processing data."
        case .low:
            return "Verified all cells\(ftDaysSuffix)."
        case .lowMonitor:
            return "Monitoring the connected cell and verified the remaining cells."
        case let .medium(cause):
            return cause.text()
        case let .high(cellCount):
            return "Detected \(cellCount) suspicious \(cellCount == 1 ? "cell" : "cells")\(ftDaysSuffix)."
        }
    }

    // as shown in risk explanation
    func verboseDescription() -> String {
        @AppStorage(UserDefaultsKeys.study.rawValue) var studyParticipationTimestamp: Double = 0
        let ftDaysSuffix = UserDefaults.standard.dataCollectionMode() != .none ? " collected in the last 14 days" : ""

        let explanationSuffix = "In most cases, cellular anomalies can be explained by non-malicious network settings: The ALS scores trigger when your network provider legitimately sets up new cells, authentication fails when your iPhone connects to third-party cells to enable emergency calls during lousy network coverage, and bandwidth decreases for high-user-density environments.\n\nWe recommend taking a detailed look into the scores and manually comparing the detection result with the actual circumstances of the anomaly detection."

        let studySuffix = studyParticipationTimestamp == 0 ? "The CellGuard team is studying fake base station behavior and countermeasures! As a next step in the fight against fake base stations, we recommend that you participate in our study." : "By participating in the study, you did everything possible to uncover fake base station abuse. The CellGuard team is actively analyzing and studying fake base station behavior and countermeasures!"

        switch self {
        case .unknown:
            return "CellGuard is still collecting and processing data, your current risk status is unknown."
        case .low:
            return "CellGuard verified all cells\(ftDaysSuffix). No anomalies were detected."
        case .lowMonitor:
            return "CellGuard is monitoring the connected cell and verified the remaining cells. No anomalies were detected."
        case let .medium(cause):
            switch cause {
            case .cells:
                return "\(cause.text())\n\n\(explanationSuffix)"
            default:
                return cause.text()
            }
        case let .high(cellCount):
            return "Detected \(cellCount) suspicious \(cellCount == 1 ? "cell" : "cells")\(ftDaysSuffix).\n\n\(explanationSuffix)\n\n\(studySuffix)"
        }
    }

    func color(dark: Bool) -> Color {
        switch self {
        case .unknown: return dark ? Color(UIColor.systemGray6) : .gray
        case .low: return dark ? Color(.green * 0.6 + .black * 0.4) : .green
        case .lowMonitor: return dark ? Color(.green * 0.6 + .black * 0.4) : .green
        case .medium: return dark ? Color(.blue * 0.4 + .black * 0.7): .blue
        case .high: return dark ? Color(.red * 0.2 + .yellow * 0.1 + .black * 0.4) : .orange
        }
    }

}

extension RiskLevel: Comparable {
    func level() -> Int {
        switch self {
        case .low:
            return 0
        case .lowMonitor:
            return 0
        case .unknown:
            return 1
        case .medium:
            return 2
        case .high:
            return 3
        }
    }

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        return lhs.level() < rhs.level()
    }
}

extension RiskLevel {

    func isCausedByCells() -> Bool {
        switch self {
        case let .medium(cause: mediumCause):
            switch mediumCause {
            case .cells:
                return true
            default:
                return false
            }
        case .high:
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
        NBNavigationLink(value: risk) {
            VStack {
                HStack {
                    Text("\(risk.header()) Risk")
                        .font(.title2)
                        .bold()
                    Spacer()
                    if risk == .unknown {
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
        RiskIndicatorCard(risk: .unknown)
            .previewDisplayName("Unknown")
        RiskIndicatorCard(risk: .low)
            .previewDisplayName("Low")
        RiskIndicatorCard(risk: .lowMonitor)
            .previewDisplayName("Low (Monitor)")
        RiskIndicatorCard(risk: .medium(cause: .permissions))
            .previewDisplayName("Medium (Permissions)")
        RiskIndicatorCard(risk: .medium(cause: .cells(cellCount: 3)))
            .previewDisplayName("Medium (Cells)")
        RiskIndicatorCard(risk: .high(cellCount: 3))
            .previewDisplayName("High")
        RiskIndicatorCard(risk: .unknown)
            .previewDisplayName("Unknown (dark)")
            .preferredColorScheme(.dark)
        RiskIndicatorCard(risk: .low)
            .previewDisplayName("Low (dark)")
            .preferredColorScheme(.dark)
        RiskIndicatorCard(risk: .lowMonitor)
            .previewDisplayName("Low (Monitor) (dark)")
            .preferredColorScheme(.dark)
        RiskIndicatorCard(risk: .medium(cause: .permissions))
            .previewDisplayName("Medium (Permissions) (dark)")
            .preferredColorScheme(.dark)
        RiskIndicatorCard(risk: .medium(cause: .cells(cellCount: 3)))
            .previewDisplayName("Medium (Cells) (dark)")
            .preferredColorScheme(.dark)
        RiskIndicatorCard(risk: .high(cellCount: 3))
            .previewDisplayName("High (dark)")
            .preferredColorScheme(.dark)
    }
}
