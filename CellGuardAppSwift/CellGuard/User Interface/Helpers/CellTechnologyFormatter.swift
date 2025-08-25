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
        switch technology {
        case .CDMA:
            return "BSID"
        case .UMTS:
            return "LCID"
        case .LTE:
            return "ECI"
        case .NR:
            return "NCI"
        default:
            return "Cell ID"
        }
    }

    public func frequency() -> String {
        switch technology {
        case .OFF: return ""
        case .CDMA: return "Channel"
        case .GSM: return "ARFCN"
        case .UMTS: return "UARFCN"
        case .SCDMA: return "ARFCN"
        case .LTE: return "EARFCN"
        case .NR: return "NR-ARFCN"
        }
    }

    public static func from(technology: String?) -> CellTechnologyFormatter {
        // Return a default formatter if no technology is given
        guard let technology = technology?.uppercased() else {
            return CellTechnologyFormatter(technology: .LTE)
        }

        if let alsTech = ALSTechnology(rawValue: technology) {
            return CellTechnologyFormatter(technology: alsTech)
        } else {
            // Return a default formatter if the technology is not found
            // TOOD: Print error
            return CellTechnologyFormatter(technology: .LTE)
        }
    }

    public static func mapColor(_ technology: ALSTechnology) -> UIColor {
        switch technology {
        case .OFF: return .systemRed
        case .GSM: return .systemPink
        case .CDMA: return .systemPurple

        case .UMTS: return .systemOrange
        case .SCDMA: return .systemYellow

        case .LTE: return .systemBlue

        case .NR: return .systemGreen
        }
    }

    public static func userInfo(_ technology: ALSTechnology) -> String {
        switch technology {
        case .OFF: return ALSTechnology.OFF.rawValue
        case .GSM: return "2G"
        case .CDMA: return "2G & 3G"
        case .UMTS: return "3G"
        case .SCDMA: return "3G"
        case .LTE: return "4G"
        case .NR: return "5G"
        }
    }

}
