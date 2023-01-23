//
//  MapView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 07.01.23.
//

import SwiftUI
import UIKit
import MapKit
import CoreData

struct MapTabView: View {
    
    @Environment(\.managedObjectContext)
    private var managedContext: NSManagedObjectContext
    
    @EnvironmentObject
    private var locationManager: LocationDataManager
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ALSCell.imported, ascending: true)],
        predicate: NSPredicate(format: "location != nil")
    )
    private var alsCells: FetchedResults<ALSCell>

    @State private var navigationActive = false
    @State private var navigationTarget: NSManagedObjectID? = nil
    
    
    var body: some View {
        // TODO: Cluster annotations & improve performance when refreshing
        NavigationView {
            VStack {
                // https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-programmatic-navigation-in-swiftui
                // TODO: I guess this isn't liked? Better use ZStack?
                NavigationLink(isActive: $navigationActive) {
                    if let target = navigationTarget,
                       let cell = managedContext.object(with: target) as? ALSCell {
                        CellDetailsView(cell: cell)
                    } else {
                        Text("Cell not found")
                    }
                } label: {
                    EmptyView()
                }
                ALSCellMap(alsCells: alsCells) { cellID in
                    navigationTarget = cellID
                    navigationActive = true
                }
                .ignoresSafeArea()
            }
        }
    }
}

// TODO: Move to seperate files
// TODO: Update other maps
// https://developer.apple.com/documentation/mapkit/mapkit_annotations/annotating_a_map_with_custom_data

// https://www.hackingwithswift.com/quick-start/swiftui/how-to-wrap-a-custom-uiview-for-swiftui
// https://developer.apple.com/documentation/coredata/nsfetchedresultscontroller
// https://medium.com/@nimjea/mapkit-in-swiftui-c0cc2b07c28a
// https://developer.apple.com/documentation/mapkit/mapkit_annotations/annotating_a_map_with_custom_data
struct ALSCellMap: UIViewRepresentable {
    
    let alsCells: FetchedResults<ALSCell>
    let onTap: (NSManagedObjectID) -> Void
    
    @EnvironmentObject
    private var locationManager: LocationDataManager
    
    func makeUIView(context: Context) -> MKMapView {
        let location = locationManager.lastLocation ?? CLLocation(latitude: 49.8726737, longitude: 8.6516291)
        let region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        
        let mapView = MKMapView(frame: .zero)
        
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        
        mapView.setRegion(region, animated: false)
        
        // TODO: Does the reuse identifier works?
        mapView.register(
            CellAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier
        )
        mapView.register(
            CellClusterAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier
        )
        
        mapView.delegate = context.coordinator
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        let cellAnnotations = uiView.annotations
            .map { $0 as? CellAnnotation }
            .compactMap { $0 }
        
        let newIDMap = Dictionary(
            uniqueKeysWithValues: alsCells.map { ($0.objectID, $0) }
        )
        let oldIDSet = Set(cellAnnotations.map { $0.coreDataID })

        // Remove annotation which we're removed from the query result
        let removeAnnotations = cellAnnotations
            .filter { !newIDMap.keys.contains($0.coreDataID) }
        print("Removed Annotations: \(removeAnnotations.count)")
        uiView.removeAnnotations(removeAnnotations)
        
        // Add the new annotations
        let addAnnotations = newIDMap
            .filter { !oldIDSet.contains($0.key) }
            .map { CellAnnotation(cell: $0.value) }
        print("Added Annotations: \(addAnnotations.count)")
        uiView.addAnnotations(addAnnotations)
    }
    
    func makeCoordinator() -> ALSCellMapDelegate {
        return ALSCellMapDelegate(onTap: onTap)
    }
    
}

class ALSCellMapDelegate: NSObject, MKMapViewDelegate {
    
    let onTap: (NSManagedObjectID) -> Void
    
    init(onTap: @escaping (NSManagedObjectID) -> Void) {
        self.onTap = onTap
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if let annotation = view.annotation as? CellAnnotation {
            onTap(annotation.coreDataID)
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let annotation = annotation as? CellAnnotation else { return nil }
        
        return CellAnnotationView(annotation: annotation, reuseIdentifier: CellAnnotationView.ReuseID)
    }
    
}

private struct CellIdentifier: Equatable, Hashable {
    
    let technology: String?
    let country: Int32
    let network: Int32
    let area: Int32
    let cell: Int64
    
    init(cell: ALSCell) {
        self.technology = cell.technology
        self.country = cell.country
        self.network = cell.network
        self.area = cell.area
        self.cell = cell.cell
    }
    
}

private class CellAnnotation: NSObject, MKAnnotation {
    
    let coreDataID: NSManagedObjectID
    let technology: ALSTechnology
    // let identifier: CellIdentifier
    
    @objc dynamic let coordinate: CLLocationCoordinate2D
    @objc dynamic let title: String?
    @objc dynamic let subtitle: String?
    
    init(cell: ALSCell) {
        // identifier = CellIdentifier(cell: cell)
        coreDataID = cell.objectID
        technology = ALSTechnology(rawValue: cell.technology ?? "") ?? .LTE
        coordinate = CLLocationCoordinate2D(
            latitude: cell.location?.latitude ?? 0,
            longitude: cell.location?.longitude ?? 0
        )
        title = "Network \(cell.network)"
        subtitle = "Area: \(cell.area) - Cell: \(cell.cell)"
    }
    
}


private class CellAnnotationView: MKMarkerAnnotationView {
    
    // TODO: We need to set this explicity or can we throw it away?
    static let ReuseID = "alsCellAnnotation"
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = "alsCell"
        // TODO: Should we animate?
        
        canShowCallout = true
        // TODO: This this enough?
        rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(code:) has not been implemented")
    }
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
        displayPriority = .defaultLow
        markerTintColor = colorFromTechnology()
        glyphImage = UIImage(systemName: "antenna.radiowaves.left.and.right")
    }
    
    private func colorFromTechnology() -> UIColor {
        guard let annotation = annotation as? CellAnnotation else {
            return .red
        }
        
        switch (annotation.technology) {
        case .GSM:
            return .systemGreen
        case .SCDMA:
            return .systemPink
        case .LTE:
            return .systemBlue
        case .NR:
            return .systemRed
        case .CDMA:
            return .systemOrange
        }
    }
}

// https://developer.apple.com/documentation/mapkit/mkannotationview/decluttering_a_map_with_mapkit_annotation_clustering
private class CellClusterAnnotationView: MKAnnotationView {
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .circle
        
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(code:) has not been implemented")
    }
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
        
        if let cluster = annotation as? MKClusterAnnotation {
            let totalCells = cluster.memberAnnotations.count
            
            image = drawCellCount(count: totalCells)
            displayPriority = .defaultHigh
        }
    }
    
    private func drawCellCount(count: Int) -> UIImage {
        // Size of the whole drawing area including the shadow
        let drawSize = 50.0
        // Size of the white circle
        let circleSize = 35.0
        // Offset to position everything in the center of the drawing area
        let offset = (drawSize - circleSize) / 2.0
        
        // Decrase the text size if the number gets larger
        let textSize: CGFloat
        if count < 1_000_000 {
            textSize = 14
        } else if count < 1_000 {
            textSize = 16
        } else {
            textSize = 18
        }
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: drawSize, height: drawSize))
        return renderer.image { context in
            
            // Draw a shadow behind the circle
            // https://www.hackingwithswift.com/example-code/uikit/how-to-render-shadows-using-nsshadow-and-setshadow
            context.cgContext.setShadow(offset: .zero, blur: 10, color: UIColor.black.withAlphaComponent(0.5).cgColor)
            // Color the circle white
            UIColor.white.setFill()
            // Draw the circle with the specified size in the middle
            UIBezierPath(ovalIn: CGRect(x: offset, y: offset, width: circleSize, height: circleSize)).fill()
            // Reset the shadow
            context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            
            // Attributes for rendering text
            let attributes = [
                NSAttributedString.Key.foregroundColor: UIColor.black,
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: textSize)
            ]
            // The text content
            let text = "\(count)"
            // Calculate the size of the text box
            let size = text.size(withAttributes: attributes)
            // Position the text in the middle of the circle
            let rect = CGRect(
                x: offset + (circleSize / 2 - size.width / 2),
                y: offset + (circleSize / 2 - size.height / 2),
                width: size.width,
                height: size.height
            )
            // Draw the text in the rectangle
            text.draw(in: rect, withAttributes: attributes)
        }
    }
    
}

// TODO: Allow to scale elements
struct CellTowerIcon: View {
    let cell: ALSCell
    
    private init(cell: ALSCell) {
        self.cell = cell
    }
    
    var body: some View {
        Image(systemName: "antenna.radiowaves.left.and.right")
            .foregroundColor(color())
            .padding(EdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
            .font(.title2)
            .background(Circle()
                .foregroundColor(.white)
                .shadow(radius: 2)
            )
    }

    private func color() -> Color {
        // TODO: Add more colors
        switch (cell.network % 5) {
        case 0:
            return .green
        case 1:
            return .pink
        case 2:
            return .red
        case 3:
            return .blue
        case 4:
            return .orange
        default:
            return .gray
        }
    }
    
    public static func asAnnotation(cell: ALSCell) -> MapAnnotation<AnyView> {
        return MapAnnotation(coordinate: CLLocationCoordinate2D(
            latitude: cell.location?.latitude ?? 0,
            longitude: cell.location?.longitude ?? 0
        )) {
            AnyView(CellTowerIcon(cell: cell))
        }
    }
    
    public static func asAnnotation<Destination: View>(cell: ALSCell, destination: () -> Destination)
        -> MapAnnotation<NavigationLink<CellTowerIcon, Destination>> {
        return MapAnnotation(coordinate: CLLocationCoordinate2D(
            latitude: cell.location?.latitude ?? 0,
            longitude: cell.location?.longitude ?? 0
        )) {
            NavigationLink {
                destination()
            } label: {
                CellTowerIcon(cell: cell)
            }
        }
    }
    
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(LocationDataManager.shared)
    }
}
