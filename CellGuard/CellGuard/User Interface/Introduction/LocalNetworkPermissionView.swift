//
//  LocalNetworkPermission.swift
//  CellGuard
//
//  Created by Lukas Arnold on 06.01.23.
//

// TODO -- the network permission might not be needed!!

import SwiftUI

struct LocalNetworkPermissionView: View {
    var body: some View {
        VStack {
            Text("CellGuard requires permission to the local network in order to receive data from its accompanying tweak.")
                .padding()
            Button("Continue") {
                // https://stackoverflow.com/a/64242102
                _ = ProcessInfo.processInfo.hostName
            }
        }
        .padding()
    }
}

struct LocalNetworkPermission_Previews: PreviewProvider {
    static var previews: some View {
        LocalNetworkPermissionView()
    }
}
