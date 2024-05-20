//
//  SysDiagnoseView.swift
//  CellGuard
//
//  Created by jiska on 20.05.24.
//

import SwiftUI

struct SysDiagnoseView: View {
    
    @State private var action: Int? = 0
    let close: () -> Void

    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    PermissionInformation(
                        icon: "stethoscope",
                        title: "System Diagnoses",
                        description: "CellGuard captures baseband management packets using system diagnoses with a baseband mobile configuration profile.\n\nSystem diagnoses are compatible with up-to-date iPhones in Lockdown Mode.",
                        size: 120
                    )
                }
                
                // Navigate to next permission, forward closing statement
                NavigationLink(destination: LocationPermissionView{self.close()}, tag: 1, selection: $action) {}
                
                LargeButton(title: "Continue", backgroundColor: .blue) {
                    self.action = 1
                }
                
                
                Spacer()
            }
            .padding()
            // Disable the ScrollView bounce for this element
            // https://stackoverflow.com/a/73888089
            .onAppear {
                UIScrollView.appearance().bounces = false
            }
            .onDisappear {
                UIScrollView.appearance().bounces = true
            }
        }.navigationBarBackButtonHidden(true)
    }
}

struct SysDiagnoseView_Provider: PreviewProvider {
    static var previews: some View {
        SysDiagnoseView{}
    }
}
