//
//  ImportView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 02.09.23.
//

import SwiftUI
import OSLog

struct ImportView: View {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ImportView.self)
    )
    
    @State var fileImporterPresented: Bool = false
    @State var fileUrl: URL? = nil
    @State var fileSize: String? = nil
    
    @State var importInProgress: Bool = false
    @State var importFinished: Bool = false
    @State var importError: String? = nil
    
    @State var importedCells = 0
    @State var importedLocations = 0
    @State var importedPackets = 0
    
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
                .disabled(importInProgress)
                
                if let fileUrl = fileUrl {
                    KeyValueListRow(key: "Type", value: Self.guessType(url: fileUrl))
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
                Section(header: Text("Progress")) {
                    Button {
                        importInProgress = true
                        PersistenceImporter.importInBackground(url: fileUrl) { result in
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
                                ProgressView()
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
        .navigationTitle("Data")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $fileImporterPresented, allowedContentTypes: [.archive, .json]) { result in
            do {
                let url = try result.get()
                fileUrl = url
                fileSize = Self.fileSize(url: url)
            } catch {
                Self.logger.warning("Can't pick file: \(error)")
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
    
    private static func guessType(url: URL) -> String {
        let lastComponent = url.lastPathComponent
        
        if lastComponent.hasSuffix(".cells.gz") {
            return "CellGuard Data (Compressed)"
        } else if lastComponent.hasSuffix(".cells") {
            return "CellGuard Data"
        } else if lastComponent.hasPrefix("sysdiagnose") && lastComponent.hasSuffix(".tar.gz") {
            return "Sysdiagnose"
        } else {
            return "Unknown"
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
