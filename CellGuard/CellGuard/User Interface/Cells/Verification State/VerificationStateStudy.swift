//
//  VerificationStateStudy.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.06.24.
//

import CoreData
import OSLog
import SwiftUI

private enum StudyMeasurementUploadStatus {
    // Measurement will not be uploaded
    case verificationNotFinished
    case statusGood
    case noParticipation
    case joinedStudyAfter
    case otherNearbyMeasurementsSubmitted
    case studyPaused // Uploaded at a later point
    
    // Measurement will (maybe) be uploaded
    case determiningStatus
    case failed
    
    // Measurement was uploaded
    case uploadAutomatic
    case uploadFeedback
    
    func submitted() -> String {
        switch self {
        case .determiningStatus:
            return "Processing"
        case .failed:
            return "Failed"
        case .uploadAutomatic:
            return "Yes"
        case .uploadFeedback:
            return "Yes"
        default:
            return "No"
        }
    }
    
    func description() -> String {
        switch self {
        case .verificationNotFinished:
            return "Please wait until the verification is finished."
        case .statusGood:
            return "The measurement is in good standing and thus was not selected for the study."
        case .noParticipation:
            return "You've decided not to participate in the study."
        case .joinedStudyAfter:
            return "You joined the study after this measurement was recorded. You can submit it manually by providing feedback."
        case .otherNearbyMeasurementsSubmitted:
            return "The measurement was not submitted for the study as it is in temporal proximity of another measurement selected for the study. You can submit it manually by providing feedback."
        case .studyPaused:
            return "The study is currently paused and the measurements will be submitted at a later point in time."
        case .determiningStatus:
            return "CellGuard currently determines if this measurement should be submitted for the study."
        case .failed:
            return "Could not submit the measurement to the study server. Please create a bug report."
        case .uploadAutomatic:
            return "The measurement was submitted automatically for the study."
        case .uploadFeedback:
            return "The measurement was submitted manually as you've provided feedback."
        }
    }
    
    static func determineStatus(verificationState: VerificationState, verificationPipeline: VerificationPipeline, measurement: CellTweak) -> StudyMeasurementUploadStatus {
        
        // The verification is not yet complete
        if !verificationState.finished {
            return .verificationNotFinished
        }
        
        if let studyStatus = measurement.study {
            // The cell was not uploaded as it was to close to another cell which will be uploaded
            if studyStatus.skippedDueTime {
                return .otherNearbyMeasurementsSubmitted
            }
            
            // The measurement fulfills all requirements to be uploaded
            if studyStatus.uploaded == nil {
                // But something must have gone wrong
                return .failed
            }
            
            // The measurement was uploaded automatically
            if studyStatus.feedbackComment == nil && studyStatus.feedbackLevel == nil {
                return .uploadAutomatic
            }
            
            // The measurement was uploaded with user feedback
            return .uploadFeedback
        } else {
            // The cell is in good standing
            if verificationState.score >= verificationPipeline.pointsSuspicious {
                return .statusGood
            }
            
            // The user does not participate in the study
            let studyParticipationStart = UserDefaults.standard.date(forKey: UserDefaultsKeys.study.rawValue)
            guard let studyParticipationStart = studyParticipationStart else {
                return .noParticipation
            }
            
            // The cell was not uploaded because the user did not yet participate in the study
            if studyParticipationStart > measurement.collected ?? Date.distantFuture {
                return .joinedStudyAfter
            }
            
            // We're determining the cell's status
            return .determiningStatus
        }
    }
}

private struct AlertModel: Identifiable {
    var id: String { title }
    var title: String
    var message: String
}

struct VerificationStateStudyView: View {
    
    let verificationPipeline: VerificationPipeline
    
    @ObservedObject var verificationState: VerificationState
    @ObservedObject var measurement: CellTweak
    
    @AppStorage(UserDefaultsKeys.study.rawValue) var studyParticipationStart: Double = 0
    
    @State private var showFeedbackSheet = false
    @State private var alert: AlertModel? = nil
    
    init(verificationPipeline: VerificationPipeline, verificationState: VerificationState, measurement: CellTweak) {
        self.verificationPipeline = verificationPipeline
        self.verificationState = verificationState
        self.measurement = measurement
    }
    
    var body: some View {
        let studyStatus = StudyMeasurementUploadStatus.determineStatus(
            verificationState: verificationState,
            verificationPipeline: verificationPipeline,
            measurement: measurement
        )
        
        Section(header: Text("Study"), footer: Text(studyStatus.description())) {
            // We have to put the sheet and alert items down here, otherwise the Section element does not work :/
            KeyValueListRow(key: "Submitted", value: studyStatus.submitted())
                .sheet(isPresented: $showFeedbackSheet) {
                    if let cellId = verificationState.cell?.objectID {
                        VerificationStateStudyViewSheet(isPresented: $showFeedbackSheet, cell: cellId)
                    } else {
                        Text("An error occurred (Cell ID missing)")
                    }
                }
                .alert(item: $alert) { detail in
                    Alert(
                        title: Text(detail.title),
                        message: Text(detail.message)
                    )
                }
            
            // Either show the submitted feedback or allow user to create it
            if studyStatus == .uploadFeedback {
                KeyValueListRow(key: "Suggested Level", value: FeedbackRiskLevel(rawValue: measurement.study?.feedbackLevel ?? "")?.name() ?? "None")
                Text("Comment\n") + 
                Text(measurement.study?.feedbackComment ?? "None")
                    .font(.footnote)
                    .foregroundColor(.gray)
            } else {
                Button {
                    if studyParticipationStart == 0 {
                        alert = AlertModel(title: "Study Opt-in Required", message: "You have to join the study to provide feedback for the measurement.")
                        return
                    }
                    
                    showFeedbackSheet = true
                } label: {
                    Text("Provide Feedback")
                }
            }
        }
    }
}

private struct VerificationStateStudyViewSheet: View {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: VerificationStateStudyViewSheet.self)
    )
    
    @Binding var isPresented: Bool
    let cell: NSManagedObjectID
    
    @State private var riskLevel: FeedbackRiskLevel = .untrusted
    @State private var comment: String = ""
    
    @State private var submitting: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                Section (header: Text("Suggested Level"), footer: Text("Trusted cells are genuine parts of their network. Anomalous cells exhibit some unusual behavior. Suspicious cells exhibit suspicious behavior in multiple regards.")) {
                    Picker(selection: $riskLevel, label: Text("Level")) {
                        ForEach([FeedbackRiskLevel.trusted, FeedbackRiskLevel.suspicious, FeedbackRiskLevel.untrusted]) { level in
                            Text(level.name()).tag(level)
                        }
                    }
                }
                
                // Limit the length to 1000 characters
                let cutoffBinding = Binding<String> {
                    comment
                } set: { newVal in
                    comment = String(newVal.prefix(1000))
                }
                
                Section(header: Text("Comment"), footer: Text("\(String(format: "%04d", comment.count)) / 1000 characters")) {
                    TextEditor(text: cutoffBinding)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        isPresented = false
                    } label: {
                        Text("Close")
                    }
                    .disabled(submitting)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submitting = true
                        Task.detached(priority: .userInitiated) {
                            do {
                                try await StudyClient().uploadCellSamples(cells: [
                                    CellIdWithFeedback(cell: cell, feedbackComment: comment, feedbackLevel: riskLevel)
                                ])
                            } catch {
                                await Self.logger.warning("Could not upload user feedback for cell: \(error)\n\(cell)")
                            }
                            
                            await MainActor.run {
                                submitting = false
                                isPresented = false
                            }
                        }
                    } label: {
                        Text("Submit")
                    }
                    .disabled(comment.isEmpty || submitting)
                }
            }
        }
    }
    
}

