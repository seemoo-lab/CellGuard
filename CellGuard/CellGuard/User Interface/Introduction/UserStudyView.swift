//
//  UserStudyView.swift
//  CellGuard
//
//  Created by jiska on 20.05.24.
//

import SwiftUI

struct UserStudyView: View {
    
    
    @State private var action: Int? = 0
    @State private var ageConfirmation: Bool = false
    @State private var policyConfirmation: Bool = false
    let close: () -> Void

    var body: some View {
        NavigationView {
            VStack {
                
                /*
                 Text aus Ethikantrag:
                 
                 Diese App wurde von Forschenden an der Technischen Universität Darmstadt und dem Hasso-Plattner-Institut entwickelt. Mit unserer Studie wollen möchten wir herausfinden, wie häufig bösartige Mobilfunk- Basisstationen in der Praxis vorkommen, und unseren Algorithmus für deren Erkennung innerhalb von CellGuard verbessern.
                 Bösartige Mobilfunk-Basisstationen können beispielsweise Positionen von Smartphones erfassen, ihren Datenverkehr überwachen und verändern, und ein Einfallstor für die Ausnutzung von Sicherheitslücken in Smartphones sein. Wir möchten evaluieren, wie gut CellGuard Menschen vor bösartigen Mobilfunk- Basisstationen schützen kann.
                 Sie können die App ohne Teilnahme an der Studie verwenden. Wenn Sie an der Studie teilnehmen, gelten folgende Bedingungen:
                 Erfasste Daten
                 • Informationen über als potentiell bösartig detektierten Mobilfunk-Basisstationen. 
                 • Wir protokollieren Ihre Position zum Zeitpunkt einer Detektion sowie Informationen, welche die Basisstation identifizieren (Ländercode, Mobilfunkbetreibercode, Mobilfunkzellenidentifikator, Frequenz, Bandbreite, eingesetzte Funktechnologie).
                 • Zusätzlich erfassen wir die Mobilfunk- Managementpakete (QMI bzw. ARI) in einem Zeitfenster von +/- 15 Sekunden um den Zeitpunkt der Detektion bzw. den Verbindungsaufbau, bereinigt um personenspezifische Daten.
                 Freiwillig geteilte Informationen
                 • CellGuard bietet die Möglichkeit, Einstufungen der Basisstationen anzupassen und einen Kommentar zur Einstufung zu hinterlassen. Optional lassen sich diese Einstufungen und Kommentare im Rahmen der Studie teilen.
                 Dauer der Studie
                 • Solange Sie die App installiert haben und an der Studie teilnehmen wollen. 
                 • Sie können die Teilnahme jederzeit in den Einstellungen beenden.
                 Löschung der Daten
                 Die Erfassung der Basisstationsinformationen erfolgt anonym. Die Informationen werden einzeln pro Basisstation übertragen und können weder miteinander noch mit nutzerspezifischen Identifikationsmerkmalen verknüpft werden.
                 Datenverarbeitung
                 Alle Daten werden vertraulich behandelt und auf Servern der TU Darmstadt gespeichert. Keine weiteren Personen außerhalb des FG SEEMOO an der TU Darmstadt und der NG Cybersecurity – Mobile & Wireless am Hasso- Plattner-Institut erhalten Zugriff. Eine Identifizierung der einzelnen Teilnehmenden ist nicht möglich. Mit der Teilnahme sind keine Risiken verbunden. Die Datenverarbeitung dieser Studie geschieht nach datenschutzrechtlichen Bestimmungen der Datenschutzgrundverordnung (DSGVO) sowie des Hessischen Datenschutz- und Informationsfreiheitsgesetzes (HDSIG). Die Daten werden ausschließlich für die im Aufklärungsbogen beschriebenen Zwecke verwendet.
                 Wenn Sie an der Studie teilnehmen bestätigen Sie, dass Sie älter als 18 Jahre alt sind und diese Einverständniserklärung gelesen haben.
                 Kontaktmöglichkeiten: 
                 Dr.-Ing. Jiska Classen und Lukas Arnold 
                 (verantwortlich für Durchführung und Datenverarbeitung)
                 Emails: jiska.classen@hpi.de, larnold@seemoo.tu- darmstadt.de
                 Für weitere Fragen zum Datenschutz können kontaktiert werden:
                 Der Datenschutzbeauftragte der TU Darmstadt, Jan Hansen: datenschutz@tu-darmstadt.de
                 Der Hessische Datenschutzbeauftragte: Email:
                 poststelle@datenschutz.hessen.de
                 
                 
                 My translated version but the one on the website is better:
                 
                 
                 This app was developed by researchers at the Technical University of Darmstadt and Hasso Plattner Institute. With our study, we want to find out how common fake base stations are in practice. Moreover, we want to improve CellGuard's algorithm for detecting fake base stations.

                 Malicious fake base stations can localize smartphones, intercept and manipulate their network traffic, and can enable attackers to launch remote code execution attacks on the baseband chip.

                 You can use CellGuard without participating in the study. If you participate, the following rules apply:

                 Data Collected
                 • Information about detected base stations that are potentially malicious.
                 • Further information associated with the detection: Time and smartphone position (with added noise).
                 • Base station details: Mobile Country Code, Mobile Network Code, cell ID, frequency, bandwidth, wireless technology.
                 • Baseband management packets (QMI or ARI) on a time window of +/- 15 seconds around the malicious behavior, stripped from personal identifying data.

                 Information Shared Voluntarily
                 • CellGuard enables users to change the base station verification result and add comments. Study participants can share these cell annotations.

                 Duration of the Study
                 • As long as you have installed the app and want to participate in the study.
                 • You can stop participating at any time in the settings.

                 Data Processing
                 All data is treated confidentially and stored on servers of the TU Darmstadt. No other persons outside of SEEMOO at TU Darmstadt and the Research Group Cybersecurity – Mobile & Wireless at Hasso Plattner Institute will have access. An identification of the individual participants is not possible. There are no risks associated with participation. The data processing of this study is carried out according to the data protection regulations of the German Data Protection Regulation (DSGVO) and the Hessian Data Protection and Freedom of Information Act (HDSIG). The data will be used exclusively for the purposes described in the informed consent form.

                 If you participate in the study, you confirm that you are older than 18 years of age and have read this consent form.

                 Contact Details
                 Dr.-Ing. Jiska Classen and Lukas Arnold
                 (responsible for implementation and data processing)
                 Email: cellguard@seemoo.de

                 For further questions on data protection, you can protect the data protection officer of TU Darmstadt, Jan Hansen: datenschutz@tu-darmstadt.de
                 Hessian data protection officer: poststelle@datenschutz.hessen.de
                 
                 
                 */
                
                // TODO Änderung, müssen wir noch programmieren --- die Position mit random offset
                // TODO das Melden von Zellen mit anderer Einstufung
                ScrollView {
                    PermissionInformation(
                        icon: "person.3.fill",
                        title: "Our Study",
                        description: """
Researchers at the Technical University of Darmstadt and Hasso Plattner Institute are actively developing CellGuard. With our study, we want to find out how common fake base stations are in practice and improve CellGuard's algorithm for detecting them.

While you can use CellGuard without participating in the study, your involvement can make a significant difference. If you participate in our study, data about suspicious cells is shared with the CellGuard team. Please read our privacy policy for further details.
"""
                        ,
                        size: 120
                    )
                
                }
                

                
                VStack {
                    
                    Toggle(isOn: $ageConfirmation) {
                        Text("I am 18 years or older")
                    }
                    .toggleStyle(CheckboxToggleStyle())
                    
                    
                    HStack {
                        Toggle(isOn: $policyConfirmation) {
                            Text("I agree to the")
                                .frame(alignment: .trailing)
                        }
                        .toggleStyle(CheckboxToggleStyle())
                        
                        Link("Privacy Policy", destination: CellGuardURLs.privacyPolicy)
                            .frame(alignment: .leading)
                    }
                    
                }
                .padding(10)
                
                // navigation depends, show sysdiag instructions on non-jailbroken devices
                
                #if JAILBROKEN
                    NavigationLink(destination: LocationPermissionView{self.close()}, tag: 1, selection: $action) {}
                #else
                    NavigationLink(destination: SysDiagnoseView{self.close()}, tag: 1, selection: $action) {}
                #endif
                
                HStack {
                    
                    // Only enable button after age confirmation
                    if (ageConfirmation && policyConfirmation) {
                        Button("Participate") {
                            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: UserDefaultsKeys.study.rawValue)
                            self.action = 1
                        }
                        .buttonStyle(SmallButtonStyle())
                    } else {
                        Button("Participate") {
                        }
                        .buttonStyle(SmallButtonStyleDisabled())
                    }
                    
                    // Here, save that the user opted out (currently default)
                    Button("Don't Participate") {
                        UserDefaults.standard.set(0, forKey: UserDefaultsKeys.study.rawValue)
                        self.action = 1
                    }
                    .buttonStyle(SmallButtonStyle())
                    
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
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .navigationBarTitleDisplayMode(.inline)
    }
}


// https://sarunw.com/posts/swiftui-checkbox/
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
            
        }, label: {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.square" : "square").foregroundColor(Color(UIColor.label))
                configuration.label
                    .foregroundColor(Color(UIColor.label))
            }
        })
    }
}

// Some hack as the big button is not resizable, so we're using a smaller button here

struct SmallButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color(UIColor.systemBlue))
            .foregroundColor(Color(UIColor.white))
            //.foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 10, height: 20)))
    }
}

struct SmallButtonStyleDisabled: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color(UIColor.systemGray))
            .foregroundColor(Color(UIColor.white))
            //.foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 10, height: 20)))
    }
}



struct UserStudyView_Provider: PreviewProvider {
    static var previews: some View {
        UserStudyView{}
    }
}
