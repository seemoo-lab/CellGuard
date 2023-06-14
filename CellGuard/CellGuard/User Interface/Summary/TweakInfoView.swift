//
//  TweakInfoSheet.swift
//  CellGuard
//
//  Created by Lukas Arnold on 02.06.23.
//

import SwiftUI

struct TweakInfoView: View {
    var body: some View {
        ScrollView {
            // TODO: Improve text + Add icons
            Text("""
The CellGuard iOS app itself does not collect cell identification data. This is the task of an external component, a so-called tweak. It modifies the default behavior of iOS, but for that it requires a jailbroken iPhone.

CellGuard continuously queries this component for new data and processes it. That's why the tweak must be active alongside the app.

In the last thirty minutes the tweak was either not reachable or did not provide any new data which is unusual. Please check if it is running correctly.

For troubleshooting you can manually delete the file /var/wireless/Documents/CaptureCellsTweak/cells-cache.json and restart the CommCenter process.
""")
            .padding()
            
            // TODO: Include the last connection status
            
            // TODO: Add link to Cydia or other stores to download the tweak
        }
        .navigationTitle(Text("Tweak"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TweakInfoView_Previews: PreviewProvider {
    static var previews: some View {
        TweakInfoView()
    }
}
