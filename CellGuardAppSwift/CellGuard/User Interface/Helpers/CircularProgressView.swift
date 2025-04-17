//
//  CircularProgressView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 06.09.23.
//

import SwiftUI

struct CircularProgressView: View {
    // The nice circular progress bar of watchOS is not available on iOS 14, so we have to use another option

    // See:
    // - https://sarunw.com/posts/swiftui-circular-progress-bar/
    // - https://www.simpleswiftguide.com/how-to-build-a-circular-progress-bar-in-swiftui/

    @Binding var progress: Float

    let lineWidth = 4.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: lineWidth)
                .opacity(0.3)
                .foregroundColor(Color.gray)
            Circle()
                .trim(from: 0.0, to: CGFloat(min(self.progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .foregroundColor(Color.blue)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear)
        }
    }
}

struct CircularProgressView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            Button {

            } label: {
                HStack {
                    Text("Import")
                    Spacer()
                    CircularProgressView(progress: .constant(Float(0.5)))
                        .frame(width: 20, height: 20)
                }
            }
            .disabled(true)
        }
        .listStyle(.insetGrouped)
    }
}
