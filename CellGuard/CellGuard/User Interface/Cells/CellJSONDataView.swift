//
//  CellJSONDataView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 20.01.23.
//

import SwiftUI
import OSLog

struct CellJSONDataView: View {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CellJSONDataView.self)
    )
    
    let cell: TweakCell
    private let json: String?
    
    init(cell: TweakCell) {
        self.cell = cell
        do {
            self.json = try Self.formatJSON(json: cell.json)
        } catch {
            Self.logger.warning("Can't pretty print JSON string '\(cell.json ?? "nil")': \(error)")
            self.json = cell.json
        }
    }
    
    var body: some View {
        List {
            Section(header: Text("Precise Technology")) {
                Text(cell.preciseTechnology ?? "Not Recorded")
            }
            Section(header: Text("JSON")) {
                if let json = json {
                    Text(json)
                        .font(Font(UIFont.monospacedSystemFont(ofSize: UIFont.smallSystemFontSize, weight: .regular)))
                } else {
                    Text("No JSON Data")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Technology Details")
    }
    
    private static func formatJSON(json inputJSON: String?) throws -> String? {
        guard let inputJSON = inputJSON else {
            return nil
        }
        
        guard let inputData = inputJSON.data(using: .utf8) else {
            return nil
        }
        
        let parsedData = try JSONSerialization.jsonObject(with: inputData)
        let outputJSON = try JSONSerialization.data(withJSONObject: parsedData, options: .prettyPrinted)
        
        return String(data: outputJSON, encoding: .utf8)
    }
}

struct CellJSONDataView_Previews: PreviewProvider {
    
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        NavigationView {
            CellJSONDataView(cell: PersistencePreview.tweakCell(context: context, imported: Date()))
        }
        .environment(\.managedObjectContext, context)
    }
    
}
