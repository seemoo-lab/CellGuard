//
//  MapInfoSheet.swift
//  CellGuard
//
//  Created by Lukas Arnold on 13.09.24.
//

import SwiftUI

struct MapInfoSheet: View {

    var body: some View {
        ScrollView {
            Text("Cell Reception Map")
                .font(.title.bold())
                .padding(EdgeInsets(top: 40, leading: 20, bottom: 30, trailing: 20))

            // Inline links with SwiftUI in iOS 14 are cursed: https://betterprogramming.pub/swiftui-pain-links-in-text-b31319783c9e
            // It's way better in iOS 15: https://stackoverflow.com/a/59627066
            if #available(iOS 15, *) {
                Text("The map shows the center of a cell's reception as computed by Apple Location Services. This location does not equate to the position of a cell tower. Usually, cell tower structures hold multiple cells that point in different directions. Learn more on [wiki.opencellid.org](https://wiki.opencellid.org/wiki/FAQ#I_know_where_cell_tower_x_exactly_is_but_OpenCellID_shows_another_position) and view a map of cell tower locations on [cellmapper.net](https://www.cellmapper.net).")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EdgeInsets(top: 0, leading: 20, bottom: 10, trailing: 20))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("The map shows the center of a cell's reception as computed by Apple Location Services. This location does not equate to the position of a cell tower. Usually, cell tower structures hold multiple cells that point in different directions.")
                    Link(destination: URL(string: "https://wiki.opencellid.org/wiki/FAQ#I_know_where_cell_tower_x_exactly_is_but_OpenCellID_shows_another_position")!) {
                        Text("Learn more on wiki.opencellid.org")
                            .multilineTextAlignment(.leading)
                            .font(.footnote)
                    }
                    Link(destination: URL(string: "https://www.cellmapper.net")!) {
                        Text("View map of tower locations on cellmapper.net")
                            .multilineTextAlignment(.leading)
                            .font(.footnote)
                    }
                }
                .padding(EdgeInsets(top: 0, leading: 20, bottom: 10, trailing: 20))
            }

            Divider()

            Text("Connected Cells")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: 10, leading: 20, bottom: 5, trailing: 20))

            // Using the frame to align the text with the padding
            // See: https://stackoverflow.com/a/62091672
            Text("For performance reasons, the map solely displays the cells to which your iPhone was connected. However, Apple Location Services provides data for sounding cells your iPhone hasn't seen. In the future, we plan to add filter capabilities, enabling you to explore all of them.")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: 0, leading: 20, bottom: 10, trailing: 20))

            Divider()

            Text("Annotations")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: 10, leading: 20, bottom: 5, trailing: 20))

            Text("The balloon annotations are positioned at the center of the cell's reception radius, which Apple Location Services determined. Tap on them to reveal more information. The cell's radio access technology defines its color.")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: 0, leading: 20, bottom: 10, trailing: 20))

            VStack {
                let rats: [ALSTechnology] = [.GSM, .CDMA, .UMTS, .SCDMA, .LTE, .NR]
                ForEach(rats) { technology in
                    HStack {
                        Circle()
                            .fill(Color(CellTechnologyFormatter.mapColor(technology)))
                            .frame(width: 13, height: 13)
                        Text(technology.rawValue + " (\(CellTechnologyFormatter.userInfo(technology)))")
                        Spacer()
                    }
                }
            }
            .padding(EdgeInsets(top: 0, leading: 25, bottom: 20, trailing: 25))

        }
    }

}

#Preview {
    MapInfoSheet()
}
