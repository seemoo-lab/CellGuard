//
//  InformationContactView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.06.24.
//

import SwiftUI

struct InformationContactView: View {
    
    @AppStorage(UserDefaultsKeys.study.rawValue) var studyParticipationTimestamp: Double = 0
        
    var versionBuild: String {
        // https://stackoverflow.com/a/28153897
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "???"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String  ?? "???"
        
        return "\(version) (\(build))"
    }
    
    var body: some View {
        List {
            // TODO: Add more in-app contact options?
            
            Section(header: Text("About CellGuard")) {
                KeyValueListRow(key: "Version", value: versionBuild)
                
                Link(destination: CellGuardURLs.baseUrl) {
                    KeyValueListRow(key: "Website") {
                        Image(systemName: "link")
                    }
                }
                
                Link(destination: CellGuardURLs.privacyPolicy) {
                    KeyValueListRow(key: "Privacy Policy") {
                        Image(systemName: "link")
                    }
                }
                
                // TODO: Create GitHub project
                Link(destination: URL(string: "http://github.com/seemoo-lab/CellGuard")!) {
                    KeyValueListRow(key: "Report Issues") {
                        Image(systemName: "link")
                    }
                }
            }
            
            Section(header: Text("Developers"), footer: Text("CellGuard is a research project by the Secure Mobile Networking Lab at TU Darmstadt (SEEMOO) and the Cybersecurity - Mobile & Wireless group at the Hasso Plattner Institute (HPI).")) {
                KeyValueListRow(key: "Lukas Arnold", value: "SEEMOO")
                KeyValueListRow(key: "Jiska Classen", value: "HPI")
            }
            
            Section(header: Text("Acknowledgements")) {
                NavigationLink {
                    AcknowledgementView()
                } label: {
                    Text("Third-Party Libraries")
                }
                Link(destination: URL(string: "https://gitlab.freedesktop.org/mobile-broadband/libqmi")!, label: {
                    KeyValueListRow(key: "libqmi") {
                        Image(systemName: "link")
                    }
                })
                Link(destination: URL(string: "https://github.com/seemoo-lab/aristoteles")!, label: {
                    KeyValueListRow(key: "aristoteles") {
                        Image(systemName: "link")
                    }
                })
            }
        }
        .navigationTitle("Information & Contact")
        .listStyle(.insetGrouped)
    }
}

#Preview {
    InformationContactView()
}
