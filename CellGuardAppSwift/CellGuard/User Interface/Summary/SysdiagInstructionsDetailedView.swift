//
//  SysdiagInstructionsDetailedView.swift
//  CellGuard
//
//  Created by jiska on 20.05.24.
//

import SwiftUI

struct SysdiagInstructionsDetailedView: View {
    var body: some View {
        VStack(spacing: 0) {

            Text("Capture a Sysdiagnose")
                .font(.title)
                .fontWeight(.bold)
                .padding()
                .multilineTextAlignment(.center)

            // iPhone SE 1st gen (iPhone 8,4) has power button on the top.
            if UIDevice.modelName == "iPhone SE" {
                Image(systemName: "arrow.up")
                    .frame(width: 200, alignment: .trailing)
                    .foregroundColor(.blue)
                    .font(Font.custom("SF Pro", fixedSize: 35))
                    .padding()

                HStack {

                    VStack {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.blue)
                            .font(Font.custom("SF Pro", fixedSize: 35))
                            .frame(maxWidth: 40, alignment: .center)
                            .padding()

                        Image(systemName: "arrow.left")
                            .foregroundColor(.blue)
                            .font(Font.custom("SF Pro", fixedSize: 35))
                            .frame(maxWidth: 40, alignment: .center)
                            .padding()
                    }

                    Text("Press all buttons for 1 second!")

                }
            } else {
                // Adjust spacer depending on iPhone model
                // TODO: Check on different devices
                if !UIDevice.modelName.contains("mini") && !UIDevice.modelName.contains("SE") {
                    Spacer(minLength: 80)
                }

                HStack {
                    VStack {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.blue)
                            .font(Font.custom("SF Pro", fixedSize: 35))
                            .frame(maxWidth: 40, alignment: .center)
                            .padding()

                        Image(systemName: "arrow.left")
                            .foregroundColor(.blue)
                            .font(Font.custom("SF Pro", fixedSize: 35))
                            .frame(maxWidth: 40, alignment: .center)
                            .padding()
                    }

                    Text("Press all buttons for one second")
                        .multilineTextAlignment(.center)
                        .font(.callout)

                    Image(systemName: "arrow.right")
                        .foregroundColor(.blue)
                        .font(Font.custom("SF Pro", fixedSize: 35))
                        .frame(maxWidth: 40, alignment: .center)
                        .padding()
                }

            }

            // on iPhone SE 1st gen display we need a scroll view
            ScrollView {

                // Side Notes:
                // - There's no vibration on iPads
                // - iPhones with a home button do not take a screenshot
                // See: https://it-training.apple.com/tutorials/support/sup075
                Text("Press and hold both volume buttons and the power button for 1 second to capture a sysdiagnose. Your iPhone will vibrate and take a screenshot. CellGuard notifies you shortly after the capture has started and once it is finished. This will take a few minutes. You'll find the sysdiagnose in the System Settings.")
                    .font(.callout)
                    .foregroundColor(.gray)
                    .padding(EdgeInsets(top: 40, leading: 20, bottom: 0, trailing: 20))
                    .multilineTextAlignment(.center)

                ActiveSysdiagnoses()
                    .padding()
            }
        }
    }
}

private struct ActiveSysdiagnoses: View {

    @ObservedObject var status = SysdiagTask.status

    var body: some View {
        HStack {
            ProgressView()
            if status.activeSysdiagnoses.count > 0 {
                Text("Capturing ^[\(status.activeSysdiagnoses.count) sysdiagnose](inflect: true)")
                    .foregroundColor(.blue)
            } else {
                Text("Scanning for sysdiagnoses")
                    .foregroundColor(.gray)
            }
        }
    }

}

#Preview {
    SysdiagInstructionsDetailedView()
}
