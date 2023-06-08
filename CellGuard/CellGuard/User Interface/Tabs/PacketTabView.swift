//
//  PacketTabView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 08.06.23.
//

import SwiftUI

struct PacketTabView: View {
    var body: some View {
        NavigationView {
            VStack {
                if (true) {
                    Text("No packets so far")
                } else {
                    ScrollView {
                        // TODO: Show packets
                    }
                }
            }
            .navigationTitle("Packets")
        }
    }
}

struct PacketTabView_Previews: PreviewProvider {
    static var previews: some View {
        PacketTabView()
    }
}
