//
//  ImportView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 02.09.23.
//

import SwiftUI
import OSLog

enum ImportFileType {
    case archive
    case sysdiagnose
    case unknown

    func description() -> String {
        switch self {
        case .archive:
            return "CellGuard Archive"
        case .sysdiagnose:
            return "Sysdiagnose"
        case .unknown:
            return "Unknown"
        }
    }

    static func guess(url: URL) -> Self {
        let lastComponent = url.lastPathComponent

        if lastComponent.hasSuffix(".cells2") {
            return .archive
        } else if lastComponent.hasPrefix("sysdiagnose_") && lastComponent.hasSuffix(".gz") {
            return .sysdiagnose
        } else {
            return .unknown
        }
    }
}

private enum ImportStatus: Equatable {

    case none
    case count(ImportCount?)
    case progress(Float)
    case infinite
    case error
    case finished

    var progress: Float {
        get {
            switch self {
            case let .progress(progress): return progress
            default: return 0
            }
        }
        set {
            switch self {
            case .progress: self = .progress(newValue)
            default: break
            }
        }

    }

}

struct ImportView: View {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ImportView.self)
    )

    @State var fileImporterPresented: Bool = false
    @State var fileUrl: URL?
    let fileUrlFixed: Bool
    @State var initialFilePropertiesUpdate = true
    @State var fileSize: String?
    @State var fileType: ImportFileType?

    @State var importInProgress: Bool = false
    @State var importFinished: Bool = false
    @State var importError: Error?

    @State var importProgress = Float(-1)

    @State private var importStatusUserCells: ImportStatus = .none
    @State private var importStatusALSCells: ImportStatus = .none
    @State private var importStatusLocations: ImportStatus = .none
    @State private var importStatusPackets: ImportStatus = .none

    @State private var importStatusUnarchive: ImportStatus = .none
    @State private var importStatusExtract: ImportStatus = .none
    @State private var importStatusParse: ImportStatus = .none
    @State private var importStatusImport: ImportStatus = .none

    @State private var importNotices: [ImportNotice] = []

    @AppStorage(UserDefaultsKeys.logArchiveSpeedup.rawValue) private var logArchiveSpeedup = true

    init() {
        self.fileUrlFixed = false
    }

    init(fileUrl: URL) {
        self.fileUrlFixed = true
        self._fileUrl = State(initialValue: fileUrl)
    }

    var body: some View {
        List {
            Section(header: Text("File")) {
                Button {
                    fileImporterPresented = true
                } label: {
                    HStack {
                        Text(fileUrl?.lastPathComponent ?? "None")
                            .foregroundColor(.primary)
                            .font(fileUrl != nil ? .system(size: 14) : .body)
                        Spacer()
                        Image(systemName: "folder")
                    }
                }
                .disabled(importInProgress || fileUrlFixed)

                if fileUrl != nil {
                    KeyValueListRow(key: "Type") { () -> AnyView in
                        if let fileType = fileType {
                            return AnyView(Text(fileType.description()))
                        } else {
                            return AnyView(ProgressView())
                        }
                    }
                    KeyValueListRow(key: "Size") { () -> AnyView in
                        if let fileSize = fileSize {
                            return AnyView(Text(fileSize))
                        } else {
                            return AnyView(ProgressView())
                        }
                    }
                }
            }

            if importStatusUserCells != .none || importStatusALSCells != .none || importStatusLocations != .none || importStatusPackets != .none {
                Section(header: Text("Datasets")) {
                    ImportStatusRow("Connected Cells", $importStatusUserCells)
                    ImportStatusRow("Cell Cache", $importStatusALSCells)
                    ImportStatusRow("Locations", $importStatusLocations)
                    ImportStatusRow("Packets", $importStatusPackets)
                }
            }

            if importStatusUnarchive != .none || importStatusExtract != .none || importStatusParse != .none || importStatusImport != .none {
                Section(header: Text("System Diagnose")) {
                    ImportStatusRow("Unarchive", $importStatusUnarchive)
                    ImportStatusRow("Extract Logs", $importStatusExtract)
                    ImportStatusRow("Parse Logs", $importStatusParse)
                    ImportStatusRow("Import Data", $importStatusImport)
                }
            }

            if !importNotices.isEmpty {
                Section(header: Text("Notices")) {
                    ForEach(importNotices) { notice in
                        Text(notice.text)
                    }
                }
            }

            if let fileUrl = fileUrl {
                Section(header: Text("Actions"), footer: Text(footerInfoText())) {
                    Button {
                        importInProgress = true
                        importFile(fileUrl)
                    } label: {
                        HStack {
                            Text("Import")
                            Spacer()
                            if importInProgress {
                                if importProgress >= 0 {
                                    CircularProgressView(progress: $importProgress)
                                        .frame(width: 20, height: 20)
                                } else {
                                    ProgressView()
                                }
                            } else if importFinished {
                                if importError != nil {
                                    Image(systemName: "xmark")
                                } else {
                                    Image(systemName: "checkmark")
                                }
                            } else {
                                Image(systemName: "square.and.arrow.down")
                            }
                        }
                    }
                    .disabled(importInProgress || importFinished)
                    // TODO: Add a text or popup about the dangers of importing

                    if importFinished {
                        if let importError = importError {
                            ImportErrorView(importError)
                        }
                    }
                }
            } else {
                Section(header: Text("Sysdiagnoses"), footer: Text("You can view recorded sysdiagnoses by navigating to Settings > Privacy > Analytics & Improvements > Analytics Data. Select a 'sysdiagnose' file and share it with CellGuard to start the import.")) {
                    Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                        Text("Open Settings")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Import Data")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $fileImporterPresented, allowedContentTypes: [.archive, .json]) { result in
            do {
                let url = try result.get()
                fileUrl = url
                fileSize = nil
                fileType = nil
                updateFileProperties()
            } catch {
                Self.logger.warning("Can't pick file: \(error)")
            }
        }
        .onAppear {
            if initialFilePropertiesUpdate {
                initialFilePropertiesUpdate = false
                updateFileProperties()
            }
        }
    }

    private func importFile(_ url: URL) {
        guard let fileType = fileType else {
            return
        }

        // Use different importers based on the file type
        switch fileType {
        case .archive:
            importProgress = Float(-1)

            PersistenceCSVImporter.importInBackground(url: url) { category, currentProgress, totalProgress in
                let progress = Float(currentProgress) / Float(totalProgress)
                switch category {
                case .connectedCells:
                    importStatusUserCells = .progress(progress)
                case .alsCells:
                    importStatusALSCells = .progress(progress)
                case .locations:
                    importStatusLocations = .progress(progress)
                case .packets:
                    importStatusPackets = .progress(progress)
                case .info:
                    break
                }
            } completion: {
                finishImport(result: $0)
            }
        case .sysdiagnose:
            LogArchiveReader.importInBackground(url: url, speedup: logArchiveSpeedup) { phase, currentProgress, totalProgress in
                let progress = Float(currentProgress) / Float(totalProgress)
                switch phase {
                case .unarchiving:
                    importStatusUnarchive = .infinite
                case .extractingTar:
                    importStatusUnarchive = .finished
                    importStatusExtract = .infinite
                case .parsingLogs:
                    importStatusExtract = .finished
                    importStatusParse = .progress(progress)
                case .importingData:
                    importStatusParse = .finished
                    importStatusImport = .progress(progress)
                }
            } completion: {
                finishImport(result: $0)
            }
        case .unknown:
            break
        }
    }

    private func finishImport(result: Result<ImportResult, Error>) {
        importStatusUnarchive = .none
        importStatusExtract = .none
        importStatusParse = .none
        importStatusImport = .none

        do {
            let counts = try result.get()
            importStatusUserCells = .count(counts.cells)
            importStatusALSCells = .count(counts.alsCells)
            importStatusLocations = .count(counts.locations)
            importStatusPackets = .count(counts.packets)
            importNotices = counts.notices
            Self.logger.info("Successfully imported \(counts.cells?.count ?? 0) cells, \(counts.alsCells?.count ?? 0) ALS cells, \(counts.locations?.count ?? 0) locations, and \(counts.packets?.count ?? 0) packets.")
        } catch {
            importError = error
            Self.logger.info("Import failed due to \(error)")

        }
        importInProgress = false
        importFinished = true
    }

    private func footerInfoText() -> String {
        if importError != nil {
            return ""
        }

        if importFinished {
            // TODO: Do not increase retention if data type was not imported or if data is younger than the retention deadline
            return "Increased the packet and location retention durations to infinite. Make sure to lower them after all imported cells have been verified."
        } else {
            if fileType != .sysdiagnose {
                return "Importing data can result in incorrect analysis of previously collected data. Make sure to backup collected data beforehand."
            }
        }

        return ""
    }

    private func updateFileProperties() {
        guard let url = fileUrl else {
            return
        }

        DispatchQueue.global(qos: .utility).async {
            let fileSize = Self.fileSize(url: url)
            let fileType = ImportFileType.guess(url: url)

            // TODO: Extract device name, CG version and count from backup and show them in the UI before importing
            /* let fromName = ""
             let fromCGVersion = "" */

            DispatchQueue.main.async {
                self.fileSize = fileSize
                self.fileType = fileType

                self.importStatusUnarchive = .none
                self.importStatusExtract = .none
                self.importStatusParse = .none
                self.importStatusImport = .none

                self.importStatusUserCells = .none
                self.importStatusALSCells = .none
                self.importStatusLocations = .none
                self.importStatusPackets = .none
            }
        }
    }

    private static func fileSize(url: URL) -> String? {
        let securityScoped = url.startAccessingSecurityScopedResource()
        defer { if securityScoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attributes[FileAttributeKey.size] as? UInt64 {
                return ByteCountFormatter().string(fromByteCount: Int64(size))
            }
        } catch {
            Self.logger.warning("Can't get file size of \(url)")
        }

        return nil
    }
}

private struct ImportStatusRow: View {

    let text: String
    @Binding var status: ImportStatus

    init(_ text: String, _ status: Binding<ImportStatus>) {
        self.text = text
        self._status = status
    }

    var body: some View {
        if detailContentLink {
            NavigationLink {
                detailContent
                    .navigationTitle(text)
            } label: {
                row
            }
        } else {
            row
        }
    }

    var row: some View {
        HStack {
            Text(text)
            Spacer()
            content
        }
    }

    var content: AnyView {
        switch status {
        case .none:
            return AnyView(EmptyView())
        case let .count(count):
            return AnyView(Text("\(count?.count ?? 0)"))
        case .progress:
            return AnyView(CircularProgressView(progress: $status.progress)
                .frame(width: 20, height: 20))
        case .infinite:
            return AnyView(ProgressView())
        case .error:
            return AnyView(Image(systemName: "xmark").foregroundColor(.gray))
        case .finished:
            return AnyView(Image(systemName: "checkmark").foregroundColor(.gray))
        }
    }

    var detailContentLink: Bool {
        switch status {
        case let .count(count):
            if count?.first != nil && count?.last != nil {
                return true
            } else {
                return false
            }
        default:
            return false
        }
    }

    var detailContent: AnyView {
        switch status {
        case let .count(count):
            if let firstDate = count?.first, let lastDate = count?.last {
                return AnyView(List {
                    KeyValueListRow(key: "Imported Entries", value: "\(count?.count ?? 0)")
                    KeyValueListRow(key: "First", value: mediumDateTimeFormatter.string(from: firstDate))
                    KeyValueListRow(key: "Last", value: mediumDateTimeFormatter.string(from: lastDate))
                })
            } else {
                // We can't offer any additional information
                return AnyView(EmptyView())
            }
        default:
            return AnyView(EmptyView())
        }
    }
}

private struct ImportErrorView: View {

    let error: Error

    init(_ error: Error) {
        self.error = error
    }

    var body: some View {
        if let error = error as? LocalizedError {
            if let recoverySuggestion = error.recoverySuggestion {
                Text(error.localizedDescription + " " + recoverySuggestion)
            } else {
                Text(error.localizedDescription)
            }

            if let failureReason = error.failureReason {
                NavigationLink {
                    ScrollView {
                        Text(failureReason)
                            .font(.body)
                            .padding()
                    }
                    .navigationTitle("Failure Reason")
                } label: {
                    Text("Failure Reason")
                }
            }

            // TODO: Enable issues & create template & link to template
            Link(destination: URL(string: "http://github.com/seemoo-lab/CellGuard")!) {
                KeyValueListRow(key: "Report on GitHub") {
                    Image(systemName: "link")
                }
            }
        } else {
            Text(error.localizedDescription)
        }
    }

}

struct ImportView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ImportView()
        }
    }
}
