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

                    Text("Press all buttons for one second!")

                    Image(systemName: "arrow.right")
                        .foregroundColor(.blue)
                        .font(Font.custom("SF Pro", fixedSize: 35))
                        .frame(maxWidth: 40, alignment: .center)
                        .padding()
                }

            }

            // on iPhone SE 1st gen display we need a scroll view
            ScrollView {

                Spacer()

                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.blue)
                    .font(Font.custom("SF Pro", fixedSize: 120))
                    .frame(maxWidth: 40, alignment: .center)
                    .padding()

                Spacer()

                // https://it-training.apple.com/tutorials/support/sup075
                // if we also support iPad: no vibration
                // TODO: iPhones with a home button do not take a screenshot
                // TODO: We can detect when the user takes a screenshot: https://stackoverflow.com/a/63955097
                // TODO: We can use the iPhone's gyroscope to detect the short vibration (?)
                Text("Press and hold both volume buttons and the power button for 1 to 1.5 seconds to start a sysdiagnose. You feel a short vibration when sysdiagnose starts. Your iPhone will also take a screenshot. It takes approximately 3 minutes to take a sysdiagnose. Afterwards, it appears in the system settings.")
                    .foregroundColor(.gray)
                    .padding()
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    SysdiagInstructionsDetailedView()
}
