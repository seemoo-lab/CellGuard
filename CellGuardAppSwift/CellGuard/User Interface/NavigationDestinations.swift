//
//  NavigationDestinations.swift
//  CellGuard
//
//  Created by Lukas Arnold on 28.08.25.
//

import Foundation
import SwiftUI

enum CGNavigationDestinations {
    case packets
    case cells
    case operators
    case connectivity
    case summaryTab
}

struct CGNavigationViewModifier: ViewModifier {
    let destinations: CGNavigationDestinations

    func body(content: Content) -> some View {
        if destinations == .packets {
            content
                .nbNavigationDestination(for: NavObjectId<PacketARI>.self) { id in
                    id.ensure { PacketARIDetailsView(packet: $0) }
                }
                .nbNavigationDestination(for: NavObjectId<PacketQMI>.self) { id in
                    id.ensure { PacketQMIDetailsView(packet: $0) }
                }
        } else if destinations == .cells {
            content
                .nbNavigationDestination(for: NavObjectId<CellALS>.self) { id in
                    id.ensure { CellDetailsView(alsCell: $0) }
                }
                .nbNavigationDestination(for: NavObjectId<CellTweak>.self) { id in
                    id.ensure { CellDetailsView(tweakCell: $0) }
                }
                .nbNavigationDestination(for: CellDetailsNavigation.self) { nav in
                    nav.cell.ensure { cell in
                        CellDetailsView(tweakCell: cell, predicate: nav.predicate)
                    }
                }
                .nbNavigationDestination(for: CellDetailsTowerNavigation.self) { data in
                    CellDetailsTowerView(nav: data)
                }
                .nbNavigationDestination(for: TweakCellMeasurementListNav.self) { data in
                    TweakCellMeasurementList(nav: data)
                }
                .nbNavigationDestination(for: NavObjectId<VerificationState>.self) { id in
                    id.ensure { VerificationStateView(verificationState: $0) }
                }
        } else if destinations == .operators {
            content
                .nbNavigationDestination(for: [NetworkOperator].self) { ops in
                    if ops.count == 1, let op = ops.first {
                        OperatorDetailsView(netOperator: op)
                    } else {
                        OperatorDetailsListView(netOperators: ops)
                    }
                }
                .nbNavigationDestination(for: CountryDetailsNavigation<NetworkCountry>.self) { data in
                    CountryDetailsView(country: data.country, secondary: data.secondary)
                }
                .nbNavigationDestination(for: CountryDetailsNavigation<NetworkOperator>.self) { data in
                    CountryDetailsView(country: data.country, secondary: data.secondary)
                }
                .nbNavigationDestination(for: SingleCellCountryNetworkNav.self) { data in
                    SingleCellCountryNetworkView(nav: data)
                }
        } else if destinations == .connectivity {
            content
                .nbNavigationDestination(for: NavObjectId<ConnectivityEvent>.self) { id in
                    id.ensure { ConnectivityEventDetails(event: $0) }
                }
                .nbNavigationDestination(for: NavListIds<ConnectivityEvent>.self) { id in
                    id.ensure { ConnectivityEventList(events: $0) }
                }
        } else if destinations == .summaryTab {
            content
                .nbNavigationDestination(for: SummaryNavigationPath.self, destination: SummaryNavigationPath.navigate)
                .nbNavigationDestination(for: RiskLevel.self) { riskLevel in
                    RiskInfoView(risk: riskLevel)
                }
        } else {
            content
        }
    }
}

extension View {

    func cgNavigationDestinations(_ destinations: CGNavigationDestinations) -> some View {
        return modifier(CGNavigationViewModifier(destinations: destinations))
    }

}
