//
//  CellTechnologyFormatter.swift
//  CellGuard
//
//  Created by Lukas Arnold on 18.01.23.
//

import Foundation
import UIKit
import SwiftUI

struct CellTechnologyFormatter {
    
    let technology: ALSTechnology
    
    private init(technology: ALSTechnology) {
        self.technology = technology
    }
    
    public func country() -> String {
        return "MCC"
    }
    
    public func network() -> String {
        if technology == .CDMA {
            return "SID"
        }
        return "MNC"
    }
    
    public func area() -> String {
        if technology == .CDMA {
            return "NID"
        }
        if technology == .LTE || technology == .NR {
            return "TAC"
        }
        return "LAC"
    }
    
    public func cell() -> String {
        if technology == .CDMA {
            return "BSID"
        }
        
        return "Cell ID"
    }
    
    public func frequency() -> String {
        switch (technology) {
        case .CDMA: return "Bandclass"
        case .GSM: return "ARFCN"
        case .SCDMA: return "ARFCN"
        case .LTE: return "UARFCN"
        case .NR: return "NRARFCN"
        }
    }
    
    public func icon() -> Image {
        return Image(systemName: "\(iconName()).square.fill")
    }
    
    private func iconName() -> String {
        switch (technology) {
        case .CDMA: return "c"
        case .GSM: return "g"
        case .SCDMA: return "s"
        case .LTE: return "l"
        case .NR: return "n"
        }
    }
    
    func uiColor() -> Color {
        switch (technology) {
        case .CDMA: return .orange
        case .GSM: return .green
        case .SCDMA: return .pink
        case .LTE: return .blue
        case .NR: return .red
        }
    }
    
    public static func from(technology: String?) -> CellTechnologyFormatter {
        // Return a default formatter if no technology is given
        guard var technology = technology?.uppercased() else {
            return CellTechnologyFormatter(technology: .LTE)
        }
        
        // UMTS and LTE technologies are handled the same
        if technology == "UMTS" {
            technology = "LTE"
        }
        
        if let alsTech = ALSTechnology(rawValue: technology) {
            return CellTechnologyFormatter(technology: alsTech)
        } else {
            // Return a default formatter if the technology is not found
            // TOOD: Print error
            return CellTechnologyFormatter(technology: .LTE)
        }
    }
    
    public static func mapColor(technology: ALSTechnology) -> UIColor {
        switch (technology) {
        case .CDMA: return .systemOrange
        case .GSM: return .systemGreen
        case .SCDMA: return .systemPink
        case .LTE: return .systemBlue
        case .NR: return .systemRed
        }
    }
    
}
