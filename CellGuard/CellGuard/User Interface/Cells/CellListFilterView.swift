//
//  CellListFilterView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.07.23.
//

import CoreData
import SwiftUI

struct CellListFilterSettings {
    
    var status: CellListFilterStatus = .all
    
    var timeFrame: PacketFilterTimeFrame = .live
    var date: Date = Calendar.current.startOfDay(for: Date())
    
    var technology: ALSTechnology?
    var country: Int?
    var network: Int?
    var area: Int?
    var cell: Int?
    
    func applyTo(request: NSFetchRequest<VerificationState>) {
        var predicateList: [NSPredicate] = [
            NSPredicate(format: "cell != nil"),
            NSPredicate(format: "pipeline == %@", Int(primaryVerificationPipeline.id) as NSNumber)
        ]
        
        if let technology = technology {
            predicateList.append(NSPredicate(format: "cell.technology == %@", technology.rawValue))
        }
        
        if let country = country {
            predicateList.append(NSPredicate(format: "cell.country == %@", country as NSNumber))
        }
        
        if let network = network {
            predicateList.append(NSPredicate(format: "cell.network == %@", network as NSNumber))
        }
        
        if let area = area {
            predicateList.append(NSPredicate(format: "cell.area == %@", area as NSNumber))
        }
        
        if let cell = cell {
            predicateList.append(NSPredicate(format: "cell.cell == %@", cell as NSNumber))
        }

        let beginDay = Calendar.current.startOfDay(for: timeFrame == .live ? Date() : date)
        if let endDate = Calendar.current.date(byAdding: .day, value: 1, to: beginDay) {
            predicateList.append(NSPredicate(format: "%@ <= cell.collected and cell.collected <= %@", beginDay as NSDate, endDate as NSDate))
        }
        
        let thresholdSuspicious = primaryVerificationPipeline.pointsSuspicious as NSNumber
        let thresholdUntrusted = primaryVerificationPipeline.pointsUntrusted as NSNumber
        
        switch (status) {
        case .all:
            break
        case .processing:
            predicateList.append(NSPredicate(format: "finished == NO"))
        case .trusted:
            predicateList.append(NSPredicate(format: "finished == YES"))
            predicateList.append(NSPredicate(format: "score >= %@", thresholdSuspicious))
        case .suspicious:
            predicateList.append(NSPredicate(format: "finished == YES"))
            predicateList.append(NSPredicate(format: "score >= %@ and score < %@", thresholdUntrusted, thresholdSuspicious))
        case .untrusted:
            predicateList.append(NSPredicate(format: "finished == YES"))
            predicateList.append(NSPredicate(format: "score < %@", thresholdUntrusted))
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicateList)
        request.relationshipKeyPathsForPrefetching = ["cell"]
    }
    
}

enum CellListFilterStatus: String, CaseIterable, Identifiable {
    case all, processing, trusted, suspicious, untrusted
    
    var id: Self { self }
}

enum CellListFilterCustomOptions: String, CaseIterable, Identifiable {
    case all, custom
    
    var id: Self { self }
}

enum CellListFilterPredefinedOptions: String, CaseIterable, Identifiable {
    case all, predefined, custom
    
    var id: Self { self }
}

struct CellListFilterView: View {
    let close: () -> Void
    
    @Binding var settingsBound: CellListFilterSettings
    @State var settings: CellListFilterSettings = CellListFilterSettings()
    
    init(settingsBound: Binding<CellListFilterSettings>, close: @escaping () -> Void) {
        self.close = close
        self._settingsBound = settingsBound
        self._settings = State(wrappedValue: self._settingsBound.wrappedValue)
    }
    
    var body: some View {
        CellListFilterSettingsView(settings: $settings, save: {
            self.settingsBound = settings
            self.close()
        })
        .navigationTitle("Filter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                // TOOD: Somehow taps on it result in the navigation stack disappearing on iOS 14
                if #available(iOS 15, *) {
                    Button {
                        self.settingsBound = settings
                        self.close()
                    } label: {
                        Text("Apply")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}


private struct CellListFilterSettingsView: View {
    
    @Binding var settings: CellListFilterSettings
    let save: () -> Void
    
    var body: some View {
        // TODO: Somehow the Pickers that open a navigation selection menu pose an issue for the navigation bar on iOS 14
        // If the "Apply" button is pressed afterwards, the "< Back" button vanishes from the navigation bar
        Form {
            Section(header: Text("Cells")) {
                // See: https://stackoverflow.com/a/59348094
                Picker("Technology", selection: $settings.technology) {
                    Text("All").tag(nil as ALSTechnology?)
                    ForEach(ALSTechnology.allCases) { Text($0.rawValue).tag($0 as ALSTechnology?) }
                }
                
                LabelNumberField("Country", "MCC", $settings.country)
                LabelNumberField("Network", "MNC", $settings.network)
                LabelNumberField("Area", "LAC or TAC", $settings.area)
                LabelNumberField("Cell", "Cell ID", $settings.cell)
            }
            Section(header: Text("Verification")) {
                Picker("Status", selection: $settings.status) {
                    ForEach(CellListFilterStatus.allCases) { Text($0.rawValue.capitalized) }
                }
            }
            Section(header: Text("Data")) {
                Picker("Display", selection: $settings.timeFrame) {
                    Text("Live").tag(PacketFilterTimeFrame.live)
                    Text("Recorded").tag(PacketFilterTimeFrame.past)
                }
                if settings.timeFrame == .past {
                    DatePicker("Day", selection: $settings.date, in: ...Date(), displayedComponents: [.date])
                }
            }
            
            if #unavailable(iOS 15) {
                Button {
                    save()
                } label: {
                    HStack {
                        Image(systemName: "tray.and.arrow.down")
                        Text("Apply")
                        Spacer()
                    }
                }
            }
        }
    }
    
}

private struct LabelNumberField: View {
    
    let label: String
    let hint: String
    let numberBinding: Binding<Int?>
    
    init(_ label: String, _ hint: String, _ numberBinding: Binding<Int?>) {
        self.label = label
        self.hint = hint
        self.numberBinding = numberBinding
    }
    
    var body: some View {
        HStack {
            Text(label)
            TextField(hint, text: positiveNumberBinding(numberBinding))
                .multilineTextAlignment(.trailing)
        }
        .keyboardType(.numberPad)
        .disableAutocorrection(true)
    }
    
    private func positiveNumberBinding(_ property: Binding<Int?>) -> Binding<String> {
        // See: https://stackoverflow.com/a/65385643
        return Binding(
            get: {
                if let number = property.wrappedValue {
                    return String(number)
                } else {
                    return ""
                }
            },
            set: {
                if let number = Int($0), number >= 0 {
                    property.wrappedValue = number
                } else {
                    property.wrappedValue = nil
                }
            }
        )
    }

    
}

struct CellListFilterView_Previews: PreviewProvider {
    static var previews: some View {
        @State var settings = CellListFilterSettings()
        
        NavigationView {
            CellListFilterView(settingsBound: $settings) {
                // Doing nothing
            }
        }
    }
}
