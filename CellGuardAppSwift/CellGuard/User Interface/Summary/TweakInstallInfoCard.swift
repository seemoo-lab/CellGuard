//
//  TweakInfoSheet.swift
//  CellGuard
//
//  Created by Lukas Arnold on 02.06.23.
//

import CoreData
import SwiftUI

struct TweakInstallInfoCard: View {

    // Update view every 5s: https://stackoverflow.com/a/56956224
    let timer = Timer.publish(every: 5.0, on: .current, in: .common).autoconnect()

    @State private var recentPacketReceived = false

    @AppStorage(UserDefaultsKeys.mostRecentPacket.rawValue)
    private var mostRecentPacket: Double?

    @AppStorage(UserDefaultsKeys.appMode.rawValue)
    private var appMode: DataCollectionMode = .none

    var body: some View {
        if appMode == .automatic {
            ActiveTweakCard(recentPacketReceived)
                .onReceive(timer) { _ in
                    recentPacketReceived = checkRecentPacket()
                }
                .onChange(of: mostRecentPacket) { _ in
                    recentPacketReceived = checkRecentPacket()
                }
                .onAppear {
                    recentPacketReceived = checkRecentPacket()
                }
        }
    }

    func checkRecentPacket() -> Bool {
        // Check if we've imported packets in the past from a tweak
        guard let mostRecentPacket = mostRecentPacket else {
            return false
        }

        // Check if we've imported a packet from the tweak in the last 30 minutes
        let thirtyMinutesAgo = Date() - 30 * 60
        if Date(timeIntervalSince1970: mostRecentPacket) < thirtyMinutesAgo {
            return false
        }

        // We did it yay :party:
        return true
    }
}

private struct ActiveTweakCard: View {

    let recentPacketReceived: Bool

    @ObservedObject private var clientState = CPTClientState.shared

    init(_ recentPacketReceived: Bool) {
        self.recentPacketReceived = recentPacketReceived
    }

    var body: some View {
        if !recentPacketReceived {
            TweakCard(update: false)
        } else if clientState.lastConnection != nil && clientState.lastHello == nil {
            TweakCard(update: true)
        }
    }
}

private struct TweakCard: View {

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    let update: Bool

    var body: some View {
        Button {
            openURL(CellGuardURLs.installGuide)
        } label: {
            VStack {
                HStack {
                    Text("\(update ? "Update" : "Install") Tweak")
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

                    Text(text)
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

    var text: String {
        if update {
            return """
            Please update the tweak as per the instructions on our website. Your currently installed version is outdated.
            """
        } else {
            return """
        CellGuard requires an additional component modifying default system behavior to automatically collect baseband packets in jailbroken mode. Please install this component as per the instructions on our website. As of now CellGuard cannot read data from it.
        """
        }
    }

}

#Preview {
    TweakInstallInfoCard()
}
