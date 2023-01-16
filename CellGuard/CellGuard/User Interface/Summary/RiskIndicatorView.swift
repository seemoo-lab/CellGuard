//
//  RiskIndicator.swift
//  CellGuard
//
//  Created by Lukas Arnold on 16.01.23.
//

import SwiftUI

enum RiskMediumCause: String {
    case Permissions = "Ensure you've granted all required permissions"
    case Tweak = "Ensure the tweak is running on your device"
}

enum RiskLevel: Equatable {
    case Unknown
    case Low
    case Medium(cause: RiskMediumCause)
    case High(count: Int)
    
    func header() -> String {
        switch (self) {
        case .Unknown: return "Unkown"
        case .Low: return "Low"
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
        case let .Medium(cause):
            return cause.rawValue
        case let .High(count):
            return "Detected \(count) potential malicious \(count == 1 ? "cell" : "cells") in the last 14 days"
        }
    }
    
    func color() -> Color {
        switch (self) {
        case .Unknown: return .gray
        case .Low: return .green
        case .Medium: return .yellow
        case .High: return .red
        }
    }
}

struct RiskIndicatorView: View {
    
    let risk: RiskLevel
    let onTap: (RiskLevel) -> Void
    
    var body: some View {
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
                    .padding()
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                .foregroundColor(risk.color())
                .shadow(color: .black.opacity(0.2), radius: 8)
        )
        .foregroundColor(.white)
        .padding()
        .onTapGesture {
            onTap(risk)
        }
    }
}

struct RiskIndicator_Previews: PreviewProvider {
    static var previews: some View {
        RiskIndicatorView(risk: .Unknown, onTap: { _ in })
            .previewDisplayName("Unknown")
        RiskIndicatorView(risk: .Low, onTap: { _ in })
            .previewDisplayName("Low")
        RiskIndicatorView(risk: .Medium(cause: .Permissions), onTap: { _ in })
            .previewDisplayName("Medium")
        RiskIndicatorView(risk: .High(count: 3), onTap: { _ in })
            .previewDisplayName("High")
    }
}
