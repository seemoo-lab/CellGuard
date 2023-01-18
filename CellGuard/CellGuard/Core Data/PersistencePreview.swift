//
//  PersistencePreview.swift
//  CellGuard
//
//  Created by Lukas Arnold on 08.01.23.
//

import Foundation
import CoreData

struct PersistencePreview {
    
    static func location(context: NSManagedObjectContext, error: Double) -> Location {
        let location = Location(context: context)
        
        location.latitude = 49.8726737 + Double.random(in: -error..<error)
        location.longitude = 8.6516291 + Double.random(in: -error..<error)
        location.horizontalAccuracy = 2 + Double.random(in: -0.5..<0.5)

        return location
    }
    
    static func tweakCell(context: NSManagedObjectContext, imported: Date) -> TweakCell {
        let cell = TweakCell(context: context)
        cell.technology = "LTE"
        cell.status = CellStatus.imported.rawValue
        cell.country = 262
        cell.network = 2
        cell.area = Int32.random(in: 1..<5000)
        cell.cell = Int64.random(in: 1..<50000)
        cell.collected = Calendar.current.date(byAdding: .day, value: -Int.random(in: 0..<3), to: Date())
        cell.imported = imported
        cell.location = location(context: context, error: 0.005)
        cell.location?.imported = cell.imported
        
        return cell
    }
    
    static func tweakCell(context: NSManagedObjectContext, from alsCell: ALSCell) -> TweakCell {
        let cell = TweakCell(context: context)
        cell.technology = alsCell.technology
        cell.country = alsCell.country
        cell.network = alsCell.network
        cell.area = alsCell.area
        cell.cell = alsCell.cell
        cell.collected = Calendar.current.date(byAdding: .day, value: -Int.random(in: 0..<3), to: Date())
        cell.imported = Calendar.current.date(byAdding: .hour, value: -Int.random(in: 0..<24), to: alsCell.imported!)
        cell.location = location(context: context, error: 0.01)
        cell.location?.imported = cell.imported
        
        return cell

    }
    
    static func alsCell(context: NSManagedObjectContext) -> ALSCell {
        let cell = ALSCell(context: context)
        cell.technology = "LTE"
        cell.country = 262
        cell.network = Int32.random(in: 0..<5)
        cell.area = Int32.random(in: 1..<5000)
        cell.cell = Int64.random(in: 1..<50000)
        cell.imported = Calendar.current.date(byAdding: .day, value: -Int.random(in: 0..<3), to: Date())
        cell.location = location(context: context, error: 0.005)
        cell.location?.imported = cell.imported
        
        for _ in 0...Int.random(in: 2..<7) {
            _ = PersistencePreview.tweakCell(context: context, from: cell)
        }

        return cell
    }
    
    static func controller() -> PersistenceController {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        let importedDate = Date()
        
        for _ in 0..<10 {
            // TODO: One cell at multiple dates
            _ = tweakCell(context: viewContext, imported: importedDate)
            _ = alsCell(context: viewContext)
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
    
}
