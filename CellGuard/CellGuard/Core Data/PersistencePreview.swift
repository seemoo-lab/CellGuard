//
//  PersistencePreview.swift
//  CellGuard
//
//  Created by Lukas Arnold on 08.01.23.
//

import Foundation
import CoreData

func previewPersistenceController() -> PersistenceController {
    let result = PersistenceController(inMemory: true)
    let viewContext = result.container.viewContext
    
    let calendar = Calendar.current
    let importedDate = Date()
    
    for _ in 0..<10 {
        // TODO: One cell at multiple dates
        let newCell = TweakCell(context: viewContext)
        newCell.technology = "LTE"
        newCell.country = 262
        newCell.network = 2
        newCell.area = Int32.random(in: 1..<5000)
        newCell.cell = Int64.random(in: 1..<50000)
        newCell.collected = calendar.date(byAdding: .day, value: -Int.random(in: 0..<3), to: Date())
        newCell.imported = importedDate
    }
    do {
        try viewContext.save()
    } catch {
        // Replace this implementation with code to handle the error appropriately.
        // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        let nsError = error as NSError
        fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
    }
    return result
}
