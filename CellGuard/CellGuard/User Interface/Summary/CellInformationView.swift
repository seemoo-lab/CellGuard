//
//  CellInformation.swift
//  CellGuard
//
//  Created by Lukas Arnold on 16.01.23.
//

import SwiftUI
import MapKit

struct CellInformationView: View {
    
    let dateFormatter = RelativeDateTimeFormatter()
    let cell: TweakCell
    
    var body: some View {
        let status = CellStatus(rawValue: cell.status ?? CellStatus.imported.rawValue)
        
        // TODO: Also display as card
        VStack {
            HStack {
                Text("Active Cell")
                    .font(.title2)
                    .bold()
                Spacer()
                if status == .verified {
                    Image(systemName: "lock.shield")
                        .font(.title2)
                        .foregroundColor(.green)
                } else if status == .failed {
                    Image(systemName: "exclamationmark.shield")
                        .font(.title2)
                        .foregroundColor(.red)
                } else {
                    ProgressView()
                }
            }
            .padding(EdgeInsets(top: 20, leading: 20, bottom: 10, trailing: 20))
            
            HStack {
                CellInformationItem(title: "MCC", number: cell.country)
                CellInformationItem(title: "MNC", number: cell.network)
                // TODO: Adapt
                CellInformationItem(title: "TAC", number: cell.area)
                CellInformationItem(title: "Cell", number: cell.cell)
            }
            .padding(EdgeInsets(top: 5, leading: 20, bottom: 10, trailing: 20))
            
            // TODO: Store correct bands
            HStack {
                CellInformationItem(title: "Technology", text: cell.technology)
                // TODO: Adapt
                CellInformationItem(title: "AFRCN", number: cell.band)
                CellInformationItem(
                    title: "Date",
                    text: dateFormatter.localizedString(for: cell.collected ?? cell.imported ?? Date(), relativeTo: Date())
                )
            }
            .padding(EdgeInsets(top: 5, leading: 20, bottom: cell.location == nil ? 25 : 10, trailing: 20))
            
            if let location = cell.location {
                CellInformationMap(coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude))
                    .frame(height: 200)
            }
        }
        .frame(maxWidth: .infinity)
        .cornerRadius(10)
        .background(
            RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 8)
        )
        // .foregroundColor(.white)
        .padding()
        

        // TODO: Put map below
    }
}

private struct CellInformationItem: View {
    
    let title: String
    let text: String?
    
    init(title: String, number: Int32) {
        self.title = title
        self.text = self.numberFormatter.string(from: number as NSNumber)
    }
    
    init(title: String, number: Int64) {
        self.title = title
        self.text = self.numberFormatter.string(from: number as NSNumber)
    }
    
    init(title: String, text: String?) {
        self.title = title
        self.text = text
    }
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
            Text(text ?? "-")
        }
        .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
    }
    
    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.usesSignificantDigits = false
        return formatter
    }()
    
}

private struct CoordinateIdentifable: Identifiable {
    
    let index: Int
    let coordinate: CLLocationCoordinate2D
    
    init(_ index: Int, _ coordinate: CLLocationCoordinate2D) {
        self.index = index
        self.coordinate = coordinate
    }
    
    var id: Int {
        return index
    }
}

private struct CellInformationMap: View {
    
    var coordinate: CLLocationCoordinate2D
    
    var body: some View {
        Map(
            coordinateRegion: .constant(region),
            interactionModes: MapInteractionModes(),
            showsUserLocation: true,
            annotationItems: [CoordinateIdentifable(0, coordinate)],
            annotationContent: { MapMarker(coordinate: $0.coordinate, tint: .red) }
        )
    }
    
    var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }
    
}

struct CellInformation_Previews: PreviewProvider {
    static var previews: some View {
        CellInformationView(cell: exampleCell())
            .previewDisplayName("iPhone 14 Pro")
        
        /* CellInformationView(cell: exampleCell())
            .previewDevice("iPhone SE (3rd generation)")
            .previewDisplayName("iPhone SE") */
    }
    
    private static func exampleCell() -> TweakCell {
        let context = PersistenceController.preview.container.viewContext
        
        let location = Location(context: context)
        location.latitude = 49.8726737
        location.longitude = 8.6516291
        location.horizontalAccuracy = 2
        location.collected = Date()
        location.imported = Date()
        
        let cell = TweakCell(context: PersistenceController.preview.container.viewContext)
        cell.status = CellStatus.imported.rawValue
        cell.technology = "LTE"
        cell.band = 1600
        
        cell.country = 262
        cell.network = 2
        cell.area = 46452
        cell.cell = 15669002
        
        cell.collected = Date(timeIntervalSinceNow: -60 * 4)
        cell.imported = Date(timeIntervalSinceNow: -60 * 1)
        // cell.location = location
                
        return cell
    }
}
