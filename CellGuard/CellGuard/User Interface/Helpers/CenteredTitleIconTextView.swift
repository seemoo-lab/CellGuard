//
//  PermissionInformation.swift
//  CellGuard
//
//  Created by jiska on 20.05.24.
//

import SwiftUI

struct CenteredTitleIconTextView: View {
    
    let icon: String
    let title: String
    let description: String
    let size: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            
            Text(self.title)
                .font(.title)
                .fontWeight(.bold)
                .padding()
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Image(systemName: self.icon)
                .foregroundColor(.blue)
                // We're using a fixed font size as the icons should always be the same size
                // https://sarunw.com/posts/how-to-change-swiftui-font-size/
                .font(Font.custom("SF Pro", fixedSize: self.size))
                .frame(maxWidth: 40, alignment: .center)
                .padding()
            
            Spacer()
                
            
            Text(self.description)
                .foregroundColor(.gray)
                .padding()
                .multilineTextAlignment(.center)
            
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
}

struct CenteredTitleIconTextView_Preview: PreviewProvider {
    static var previews: some View {
        CenteredTitleIconTextView(icon: "antenna.radiowaves.left.and.right",
                              title: "Name of the Permission Request",
                              description: "Why we need this permission...",
                              size: 120)
    }
}
