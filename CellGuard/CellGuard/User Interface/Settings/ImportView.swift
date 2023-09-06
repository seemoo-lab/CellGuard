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
    case sysdiagnose
    case unknown
    
    func description() -> String {
        switch(self) {
        case .dataUncompressed:
            return "CellGuard Data (Compressed)"
        case .dataCompressed:
            return "CellGuard Data"
        case .sysdiagnose:
            return "Sysdiagnose"
        case .unknown:
            return "Unknown"
        }
    }
    
    static func guess(url: URL) -> Self {
        let lastComponent = url.lastPathComponent
        
        if lastComponent.hasSuffix(".cells.gz") {
            return .dataCompressed
        } else if lastComponent.hasSuffix(".cells") {
            return .dataUncompressed
        } else if lastComponent.hasPrefix("sysdiagnose") && lastComponent.hasSuffix(".tar.gz") {
            return .sysdiagnose
        } else {
            return .unknown
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
    
    @State var importProgress = Float(0)
    
    @State var importedCells = 0
    @State var importedLocations = 0
    @State var importedPackets = 0
    
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
            
            if let fileUrl = fileUrl {
                Section(header: Text("Actions"), footer: Text("Importing data can result in incorrect analysis of previously collected data. Make sure to backup collected data beforehand.")) {
                    Button {
                        importInProgress = true
                        // TODO: Use different importers based on the file type
                        PersistenceImporter.importInBackground(url: fileUrl) { currentProgress, totalProgress in
                            importProgress = Float(currentProgress) / Float(totalProgress)
                        } completion: { result in
                            do {
                                let counts = try result.get()
                                importedCells = counts.cells
                                importedLocations = counts.locations
                                importedPackets = counts.packets
                                Self.logger.info("Successfully imported \(counts.cells) cells, \(counts.locations) locations, and \(counts.packets) packets.")
                            } catch {
                                importError = error.localizedDescription
                                Self.logger.info("Import failed due to \(error)")
                                
                            }
                            importInProgress = false
                            importFinished = true
                        }
                    } label: {
                        HStack {
                            Text("Import")
                            Spacer()
                            if importInProgress {
                                CircularProgressView(progress: $importProgress)
                                    .frame(width: 20, height: 20)
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
                            Text(importError)
                        } else {
                            // TODO: Update values during the import process
                            KeyValueListRow(key: "Cells", value: "\(importedCells)")
                            KeyValueListRow(key: "Locations", value: "\(importedLocations)")
                            KeyValueListRow(key: "Packets", value: "\(importedPackets)")
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
    
    private func updateFileProperties() {
        guard let url = fileUrl else {
            return
        }
        
        DispatchQueue.global(qos: .utility).async {
            let fileSize = Self.fileSize(url: url)
            let fileType = ImportFileType.guess(url: url)
            DispatchQueue.main.async {
                self.fileSize = fileSize
                self.fileType = fileType
            }
        }
    }
    
    private static func fileSize(url: URL) -> String? {
        guard url.startAccessingSecurityScopedResource() else {
            return nil
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attributes[FileAttributeKey.size] as? NSNumber {
                return ByteCountFormatter().string(fromByteCount: size.int64Value)
            }
        } catch {
            Self.logger.warning("Can't get file size of \(url)")
        }
        
        return nil
    }
}

struct ImportView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ImportView()
        }
    }
}
