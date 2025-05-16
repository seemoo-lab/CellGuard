//
//  CellInformation.swift
//  CellGuard
//
//  Created by Lukas Arnold on 16.01.23.
//

import UIKit
import MapKit
import SwiftUI

struct CellInformationCard: View {

    let cell: CellTweak
    let dualSim: Bool

    init(cell: CellTweak, dualSim: Bool = false) {
        self.cell = cell
        self.dualSim = dualSim
    }

    var body: some View {
        let disconnected = cell.technology == ALSTechnology.OFF.rawValue

        if disconnected {
            CellInfoCardOutline(cell: cell, dualSim: dualSim, disconnected: disconnected)
        } else {
            NavigationLink {
                CellDetailsView(tweakCell: cell)
            } label: {
                CellInfoCardOutline(cell: cell, dualSim: dualSim, disconnected: disconnected)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct CellInfoCardOutline: View {
    let cell: CellTweak
    let dualSim: Bool
    let disconnected: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack {
            if disconnected {
                DisconnectedCellInfoCard(cell: cell, dualSim: dualSim)
            } else {
                ConnectedCellInfoCard(cell: cell, dualSim: dualSim)
            }
        }
        .frame(maxWidth: .infinity)
        .cornerRadius(10)
        .background(
            RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                .foregroundColor(colorScheme == .dark ? Color(UIColor.systemGray6) : .white)
                .shadow(color: .black.opacity(0.2), radius: 8)
        )
        // .foregroundColor(.white)
        .padding()
    }
}

private struct DisconnectedCellInfoCard: View {
    let dateFormatter = RelativeDateTimeFormatter()
    let cell: CellTweak
    let dualSim: Bool

    var body: some View {
        HStack {
            Text("Cell")
                .font(.title2)
                .bold()

            if dualSim {
                HStack(spacing: 2) {
                    Image(systemName: "simcard")
                    Text("\(cell.simSlotID)")
                }
            }

            Spacer()
        }
        .padding(EdgeInsets(top: 20, leading: 20, bottom: 10, trailing: 20))

        HStack {
            CellInformationItem(title: "Status", text: "Not connected")
            CellInformationItem(
                title: "Date",
                text: dateFormatter.localizedString(for: cell.collected ?? cell.imported ?? Date(), relativeTo: Date())
            )
        }
        .padding(EdgeInsets(top: 5, leading: 20, bottom: cell.location == nil ? 25 : 10, trailing: 20))
    }
}

private struct ConnectedCellInfoCard: View {
    let dateFormatter = RelativeDateTimeFormatter()
    let cell: CellTweak
    let dualSim: Bool

    @FetchRequest private var alsCells: FetchedResults<CellALS>
    @FetchRequest private var tweakCells: FetchedResults<CellTweak>

    private let techFormatter: CellTechnologyFormatter

    init(cell: CellTweak, dualSim: Bool = false) {
        self.cell = cell
        self.techFormatter = CellTechnologyFormatter.from(technology: cell.technology)
        self.dualSim = dualSim

        self._alsCells = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \CellALS.imported, ascending: false)],
            predicate: PersistenceController.shared.sameCellPredicate(cell: cell, mergeUMTS: true),
            animation: .default
        )
        self._tweakCells = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \CellTweak.collected, ascending: false)],
            predicate: PersistenceController.shared.sameCellPredicate(cell: cell, mergeUMTS: false),
            animation: .default
        )
    }

    var body: some View {
        HStack {
            Text("Cell")
                .font(.title2)
                .bold()

            if dualSim {
                HStack(spacing: 2) {
                    Image(systemName: "simcard")
                    Text("\(cell.simSlotID)")
                }
            }

            Spacer()
            if let state = tweakCells.first?.primaryVerification {
                CellStatusIcon(state: state)
            } else {
                ProgressView()
            }
        }
        .padding(EdgeInsets(top: 20, leading: 20, bottom: 10, trailing: 20))

        HStack {
            CellInformationItem(title: techFormatter.country(), number: cell.country)
            CellInformationItem(title: techFormatter.network(), text: formatMNC(cell.network))
            CellInformationItem(title: techFormatter.area(), number: cell.area)
            CellInformationItem(title: techFormatter.cell(), number: cell.cell)
        }
        .padding(EdgeInsets(top: 5, leading: 15, bottom: 10, trailing: 15))

        HStack {
            let technology = cell.supports5gNsa() ? "5G NSA" : cell.technology
            CellInformationItem(title: "Technology", text: technology)
            // CellInformationItem(title: techFormatter.frequency(), number: cell.frequency)
            CellInformationItem(
                title: "Date",
                text: dateFormatter.localizedString(for: cell.collected ?? cell.imported ?? Date(), relativeTo: Date())
            )
        }
        .padding(EdgeInsets(top: 5, leading: 20, bottom: cell.location == nil ? 25 : 10, trailing: 20))

        if SingleCellMap.hasAnyLocation(alsCells, tweakCells) {
            SingleCellMap(alsCells: alsCells, tweakCells: tweakCells)
                .frame(height: 200)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
    }
}

private struct CellInformationItem: View {

    let title: String
    let text: String?

    init(title: String, text: String) {
        self.title = title
        self.text = text
    }

    init(title: String, number: Int32) {
        self.title = title
        self.text = plainNumberFormatter.string(from: number as NSNumber)
    }

    init(title: String, number: Int64) {
        self.title = title
        self.text = plainNumberFormatter.string(from: number as NSNumber)
    }

    init(title: String, text: String?) {
        self.title = title
        self.text = text
    }

    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
            Text(text ?? "-")
        }
        .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
    }

}

private struct CoordinateIdentifiable: Identifiable {

    let index: Int

    init(_ index: Int) {
        self.index = index
    }

    var id: Int {
        return index
    }
}

struct CellInformation_Previews: PreviewProvider {
    static var previews: some View {
        CellInformationCard(cell: exampleCell())
            .previewDisplayName("iPhone 14 Pro")

        /* CellInformationView(cell: exampleCell())
            .previewDevice("iPhone SE (3rd generation)")
            .previewDisplayName("iPhone SE") */
    }

    private static func exampleCell() -> CellTweak {
        let context = PersistenceController.preview.container.viewContext

        let location = LocationUser(context: context)
        location.latitude = 49.8726737
        location.longitude = 8.6516291
        location.horizontalAccuracy = 2
        location.collected = Date()
        location.imported = Date()

        let cell = CellTweak(context: PersistenceController.preview.container.viewContext)
        // cell.status = CellStatus.imported.rawValue
        cell.technology = "LTE"
        cell.frequency = 1600

        cell.country = 262
        cell.network = 2
        cell.area = 46452
        cell.cell = 15669002

        cell.collected = Date(timeIntervalSinceNow: -60 * 4)
        cell.imported = Date(timeIntervalSinceNow: -60 * 1)
        // cell.location = location

        return cell
    }
}
