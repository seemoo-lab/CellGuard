//
//  TweakInfoSheet.swift
//  CellGuard
//
//  Created by Lukas Arnold on 02.06.23.
//

import CoreData
import SwiftUI

struct TweakInstallInfoCard: View {
    @FetchRequest
    private var qmiPackets: FetchedResults<PacketQMI>

    @FetchRequest
    private var ariPackets: FetchedResults<PacketARI>

    @AppStorage(UserDefaultsKeys.appMode.rawValue)
    private var appMode: DataCollectionMode = .none

    init() {
        // https://www.hackingwithswift.com/quick-start/swiftui/how-to-limit-the-number-of-items-in-a-fetch-request
        let qmiRequest: NSFetchRequest<PacketQMI> = PacketQMI.fetchRequest()
        qmiRequest.fetchBatchSize = 1
        qmiRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PacketQMI.collected, ascending: true)]

        let ariRequest: NSFetchRequest<PacketARI> = PacketARI.fetchRequest()
        ariRequest.fetchBatchSize = 1
        ariRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PacketARI.collected, ascending: true)]

        self._qmiPackets = FetchRequest(fetchRequest: qmiRequest)
        self._ariPackets = FetchRequest(fetchRequest: ariRequest)
    }

    var body: some View {
        let hasData = !qmiPackets.isEmpty || !ariPackets.isEmpty
        if !hasData && appMode == .automatic {
            TweakCard()
        } else {
            EmptyView()
        }
    }
}

private struct TweakCard: View {

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openURL(CellGuardURLs.installGuide)
        } label: {
            VStack {
                HStack {
                    Text("Install Tweak")
                        .font(.title2)
                        .bold()
                    Spacer()
                    Image(systemName: "chevron.right.circle.fill")
                        .imageScale(.large)
                }

                HStack(spacing: 0) {
                    Image(systemName: "personalhotspot")
                        .foregroundColor(.blue)
                        .font(Font.custom("SF Pro", fixedSize: 30))
                        .frame(maxWidth: 40, alignment: .center)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 10))

                    Text("""
        CellGuard requires an additional component modifying default system behavior to automatically collect baseband packets in jailbroken mode. Please install this component as per the instructions on our website. As of now CellGuard cannot read data from it.
        """)
                    .padding()
                    .multilineTextAlignment(.leading)
                }

            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                    .foregroundColor(colorScheme == .dark ? Color(UIColor.systemGray6) : .white)
                    .shadow(color: .black.opacity(0.2), radius: 8)
            )
            .foregroundColor(colorScheme == .dark ? .white : .black.opacity(0.8))
            .padding()
        }
    }

}

#Preview {
    TweakInstallInfoCard()
}
