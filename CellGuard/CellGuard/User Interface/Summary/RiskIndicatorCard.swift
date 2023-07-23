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
    case Tweak
    case Cells(cellCount: Int)
    
    func text() -> String {
        switch (self) {
        case .Permissions:
            return "Ensure you've granted all required permissions"
        case .Tweak:
            return "Ensure the tweak is active"
        case let .Cells(cellCount):
            return "Detected \(cellCount) suspicious \(cellCount == 1 ? "cell measurement" : "cell measurements") in the last 14 days"
        }
    }
}

enum RiskLevel: Equatable {
    // TODO: Show the real number of cells to be verified
    case Unknown
    case Low
    case LowMonitor
    case Medium(cause: RiskMediumCause)
    case High(cellCount: Int)
    
    func header() -> String {
        switch (self) {
        case .Unknown: return "Unkown"
        case .Low: return "Low"
        case .LowMonitor: return "Low"
        case .Medium: return "Medium"
        case .High: return "High"
        }
    }
    
    func description() -> String {
        switch (self) {
        case .Unknown:
            return "Collecting and processing data"
        case .Low:
            return "Verified all cells of the last 14 days"
        case .LowMonitor:
            return "Monitoring the connected cell and verified the remaining cells"
        case let .Medium(cause):
            return cause.text()
        case let .High(cellCount):
            return "Detected \(cellCount) potential malicious \(cellCount == 1 ? "cell measurement" : "cell measurements") in the last 14 days"
        }
    }
    
    func color(dark: Bool) -> Color {
        // TODO: Less saturated colors for the dark mode
        switch (self) {
        case .Unknown: return dark ? Color(UIColor.systemGray6) : .gray
        case .Low: return .green
        case .LowMonitor: return .green
        case .Medium: return .orange
        case .High: return .red
        }
    }
}

struct RiskIndicatorCard: View {
    
    let risk: RiskLevel
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationLink {
            RiskIndicatorLink(risk: risk)
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

private struct RiskIndicatorLink: View {
    
    let risk: RiskLevel
    
    var body: some View {
        switch (risk) {
        case .Low:
            return AnyView(CellListView())
        case .LowMonitor:
            return AnyView(CellListView())
        case let .Medium(cause):
            if cause == .Permissions {
                return AnyView(SettingsView())
            } else if cause == .Tweak {
                // TODO: Replace with help article
                return AnyView(TweakInfoView())
            } else {
                return AnyView(CellListView())
            }
        case .High(_):
            return AnyView(CellListView())
        case .Unknown:
            return AnyView(VerificationProgressView())
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
    }
}
