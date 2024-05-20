//
//  SysdiagInstructionsView.swift
//  CellGuard
//
//  Created by jiska on 20.05.24.
//

import SwiftUI

struct SysdiagInstructionsCard: View {
    
    @State private var showingSysdiagInstructions = false
    @AppStorage(UserDefaultsKeys.appMode.rawValue) var appMode: DataCollectionMode = .none
    
    var body: some View {
        
        NavigationLink(isActive: $showingSysdiagInstructions) {
            SysdiagInstructionsDetailedView()
        } label: {
            EmptyView()
        }
        
        if appMode == .manual {
            Button {
               // open instructions
                showingSysdiagInstructions = true
            } label: {
                SysdiagCard()
            }
        } else {
            EmptyView()
        }
    }
}


private struct SysdiagCard: View {
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack {
            HStack() {
                Text("Create New Sysdiagnose")
                    .font(.title2)
                    .bold()
                Spacer()
                Image(systemName: "chevron.right.circle.fill")
                    .imageScale(.large)
            }
            
            HStack(spacing: 0) {
                Image(systemName: "stethoscope")
                    .foregroundColor(.blue)
                    .font(Font.custom("SF Pro", fixedSize: 30))
                    .frame(maxWidth: 40, alignment: .center)
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 10))  
                
                Text("Follow on-screen instructions to take a new system diagnose.")
                    .multilineTextAlignment(.leading)
                    .padding()
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


#Preview {
    SysdiagInstructionsCard()
}
