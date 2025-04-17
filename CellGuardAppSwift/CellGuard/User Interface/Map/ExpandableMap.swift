//
//  ExpandableMap.swift
//  CellGuard
//
//  Created by Lukas Arnold on 19.10.24.
//

import MapKit
import SwiftUI

struct ExpandableMap<Content: View>: View {

    let map: () -> Content
    @State private var expanded: Bool = false

    init(_ map: @escaping () -> Content) {
        self.map = map
    }

    var body: some View {
        ZStack {
            // Navigation link for fullscreen view
            NavigationLink(isActive: $expanded) {
                map()
                    .ignoresSafeArea()
            } label: {
                EmptyView()
            }
            .frame(width: 0, height: 0)
            .hidden()
            .background(Color.blue)

            // Small map shown here
            map()

            // Button to open the expanded map
            HStack {
                Spacer()
                MapExpandButton {
                    expanded = true
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            // It's quite important to set the right button style, otherwise the whole map is the tap area
            // See: https://stackoverflow.com/a/70400079
            .buttonStyle(.borderless)
        }
        .frame(height: 200)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

}

private struct MapExpandButton: View {

    @Environment(\.colorScheme) var colorScheme

    private let onTap: () -> Void

    init(onTap: @escaping () -> Void) {
        self.onTap = onTap
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
        }
        .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        .roundedThinMaterialBackground(color: colorScheme)
        .padding(EdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
    }

}

@available(iOS 17, *)
#Preview {
    NavigationView {
        List {
            ExpandableMap {
                Map(coordinateRegion: .constant(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 37.768552, longitude: -122.481616),
                        latitudinalMeters: 2000, longitudinalMeters: 2000
                    )
                ))
            }
        }
    }
}
