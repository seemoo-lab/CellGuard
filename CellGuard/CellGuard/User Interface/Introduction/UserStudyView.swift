//
//  UserStudyView.swift
//  CellGuard
//
//  Created by jiska on 20.05.24.
//

import SwiftUI

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

struct UserStudyView: View {
    
    var returnToPreviousView: Bool = false
    
    @AppStorage(UserDefaultsKeys.study.rawValue) private var studyParticipationTimestamp: Double = 0
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    @State private var agePolicyConfirmation: Bool = false
    @State private var action: Int? = 0
    @State private var confirmationSheet: Bool = false
    
    var body: some View {
        VStack {
            // TODO Änderung, müssen wir noch programmieren --- die Position mit random offset
            // TODO das Melden von Zellen mit anderer Einstufung
            ScrollView {
                CenteredTitleIconTextView(
                    icon: "person.3.fill",
                    description: """
Researchers at the Technical University of Darmstadt and Hasso Plattner Institute are actively developing CellGuard. With our study, we want to find out how common fake base stations are in practice and improve CellGuard's algorithm for detecting them.

While you can use CellGuard without participating in the study, your involvement can make a significant difference. If you participate in our study, data about suspicious cells is shared with the CellGuard team. Please read our privacy policy for further details.
"""
                    ,
                    size: 120
                )
            }
            
            // navigation depends, show sysdiag instructions on non-jailbroken devices
            #if JAILBROKEN
            NavigationLink(destination: LocationPermissionView(), tag: 1, selection: $action) {}
            #else
            NavigationLink(destination: SysDiagnoseView(), tag: 1, selection: $action) {}
            #endif
            
            HStack {
                Toggle(isOn: $agePolicyConfirmation) {
                    Text("I'm over 18 years or older and agree to the privacy policy.")
                }
                .toggleStyle(CheckboxStyle())
                
                Link(destination: CellGuardURLs.privacyPolicy) {
                    Image(systemName: "link")
                        .font(.system(size: 20))
                }
            }
            .padding(EdgeInsets(top: 2, leading: 10, bottom: 0, trailing: 10))
            
            HStack {
                // Here, save that the user agreed to join the study
                Button {
                    studyParticipationTimestamp = Date().timeIntervalSince1970
                    nextView()
                } label: {
                    Text("Participate")
                }
                .buttonStyle(SmallButtonStyle())
                .padding(3)
                .disabled(!agePolicyConfirmation)
                
                
                // Here, save that the user opted out (currently default)
                Button {
                    studyParticipationTimestamp = 0
                    nextView()
                } label: {
                    Text("Don't Participate")
                }
                .buttonStyle(SmallButtonStyle())
                .padding(3)
            }
            .padding(EdgeInsets(top: 2, leading: 10, bottom: 6, trailing: 10))
        }
        .navigationTitle("Our Study")
        .navigationBarTitleDisplayMode(returnToPreviousView ? .automatic : .large)
    }
    
    func nextView() {
        if returnToPreviousView {
            self.presentationMode.wrappedValue.dismiss()
        } else {
            self.action = 1
        }
    }
}

// See: https://stackoverflow.com/a/65895802

private struct CheckboxStyle: ToggleStyle {
    
    func makeBody(configuration: Self.Configuration) -> some View {
        return HStack {
            Image(systemName: configuration.isOn ? "checkmark.circle" : "circle")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(configuration.isOn ? .blue : .gray)
                .font(.system(size: 20, weight: .regular, design: .default))
                configuration.label
        }
        .onTapGesture { configuration.isOn.toggle() }
    }
}

// Some hack as the big button is not resizable, so we're using a smaller button here

private struct SmallButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        let foregroundColor = Color(UIColor.white)
        let backgroundColor = Color(UIColor.systemBlue)
        
        let confForegroundColor = !isEnabled || configuration.isPressed ? foregroundColor.opacity(0.3) : foregroundColor
        let confBackgroundColor = !isEnabled || configuration.isPressed ? backgroundColor.opacity(0.3) : backgroundColor
        
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(confBackgroundColor)
            .foregroundColor(confForegroundColor)
            //.foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 10, height: 20)))
    }
}

#Preview {
    NavigationView {
        UserStudyView()
    }
}
