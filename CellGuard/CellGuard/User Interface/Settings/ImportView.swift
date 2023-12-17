//
//  ImportView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 02.09.23.
//

import SwiftUI
import OSLog

enum ImportFileType {
    case dataUncompressed
    case dataCompressed
    case archive
    case sysdiagnose
    case unknown
    
    func description() -> String {
        switch(self) {
        case .dataUncompressed:
            return "CellGuard Data (Compressed)"
        case .dataCompressed:
            return "CellGuard Data"
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
        } else if lastComponent.hasSuffix(".cells.gz") {
            return .dataCompressed
        } else if lastComponent.hasSuffix(".cells") {
            return .dataUncompressed
        } else if lastComponent.hasPrefix("sysdiagnose_") && lastComponent.hasSuffix(".gz") {
            return .sysdiagnose
        } else {
            return .unknown
        }
    }
}

private enum ImportStatus: Equatable {
    
    case none
    case count(Int)
    case progress(Float)
    
    var progress: Float {
        get {
            switch (self) {
            case let .progress(progress): return progress
            default: return 0
            }
        }
        set {
            switch (self) {
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
    @State var fileUrl: URL? = nil
    let fileUrlFixed: Bool
    @State var fileSize: String? = nil
    @State var fileType: ImportFileType? = nil
    
    @State var importInProgress: Bool = false
    @State var importFinished: Bool = false
    @State var importError: String? = nil
    
    @State var importProgress = Float(-1)
    
    @State private var importStatusUserCells: ImportStatus = .none
    @State private var importStatusALSCells: ImportStatus = .none
    @State private var importStatusLocations: ImportStatus = .none
    @State private var importStatusPackets: ImportStatus = .none
    
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
                            .foregroundColor(.black)
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
                    .disabled(importInProgress || importFinished || fileType == .dataCompressed)
                    // TODO: Add a text or popup about the dangers of importing
                    
                    if importFinished {
                        if let importError = importError {
                            Text(importError)
                        }
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
        .onAppear() {
            updateFileProperties()
        }
    }
    
    private func importFile(_ url: URL) {
        guard let fileType = fileType else {
            return
        }
        
        // Use different importers based on the file type
        switch (fileType) {
        case .archive:
            importProgress = Float(-1)
            
            PersistenceCSVImporter.importInBackground(url: url) { category, currentProgress, totalProgress in
                let progress = Float(currentProgress) / Float(totalProgress)
                switch (category) {
                case .connectedCells: importStatusUserCells = .progress(progress)
                case .alsCells: importStatusALSCells = .progress(progress)
                case .locations: importStatusLocations = .progress(progress)
                case .packets: importStatusPackets = .progress(progress)
                case .info: break
                }
            } completion: {
                finishImport(result: $0)
            }
            break
        case .dataCompressed:
            // TODO: Implement
            break
        case .dataUncompressed:
            PersistenceJSONImporter.importInBackground(url: url) { currentProgress, totalProgress in
                importProgress = Float(currentProgress) / Float(totalProgress)
            } completion: {
                finishImport(result: $0)
            }
        case .sysdiagnose:
            LogArchiveReader.importInBackground(url: url) { currentProgress, totalProgress in
                // TODO: Show progress
            } completion: { result in
                // TODO: Finish
            }

            break
        case .unknown:
            break
        }
    }
    
    private func finishImport(result: Result<ImportResult, Error>) {
        do {
            let counts = try result.get()
            importStatusUserCells = .count(counts.cells)
            importStatusALSCells = .count(counts.alsCells)
            importStatusLocations = .count(counts.locations)
            importStatusPackets = .count(counts.packets)
            Self.logger.info("Successfully imported \(counts.cells) cells, \(counts.locations) locations, and \(counts.packets) packets.")
        } catch {
            importError = error.localizedDescription
            Self.logger.info("Import failed due to \(error)")
            
        }
        importInProgress = false
        importFinished = true
    }
    
    private func footerInfoText() -> String {
        if importFinished {
            return "Increased the packet and location retention durations to infinite. Make sure to lower them after all imported cells have been verified."
        } else {
            return "Importing data can result in incorrect analysis of previously collected data. Make sure to backup collected data beforehand."
        }
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
        return HStack {
            Text(text)
            Spacer()
            content
        }
    }
    
    var content: AnyView {
        switch (status) {
        case .none:
            return AnyView(EmptyView())
        case let .count(count):
            return AnyView(Text("\(count)"))
        case .progress:
            return AnyView(CircularProgressView(progress: $status.progress)
                .frame(width: 20, height: 20))
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
