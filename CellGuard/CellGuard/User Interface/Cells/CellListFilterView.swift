//
//  CellListFilterView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.07.23.
//

import CoreData
import SwiftUI

struct CellListFilterSettings {
    
    var timeFrame: PacketFilterTimeFrame = .live
    var date: Date = Date()
    
    var technology: ALSTechnology?
    var country: Int?
    var network: Int?
    var area: Int?
    var cell: Int?
    
    func applyTo(request: NSFetchRequest<TweakCell>) {
        var predicateList: [NSPredicate] = []
        
        if let technology = technology {
            predicateList.append(NSPredicate(format: "technology == %@", technology.rawValue))
        }
        
        if let country = country {
            predicateList.append(NSPredicate(format: "country == %@", country as NSNumber))
        }
        
        if let network = network {
            predicateList.append(NSPredicate(format: "network == %@", network as NSNumber))
        }
        
        if let area = area {
            predicateList.append(NSPredicate(format: "area == %@", area as NSNumber))
        }
        
        if let cell = cell {
            predicateList.append(NSPredicate(format: "cell == %@", cell as NSNumber))
        }

        let beginDay = Calendar.current.startOfDay(for: timeFrame == .live ? Date() : date)
        if let endDate = Calendar.current.date(byAdding: .day, value: 1, to: beginDay) {
            predicateList.append(NSPredicate(format: "%@ <= collected and collected <= %@", beginDay as NSDate, endDate as NSDate))
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicateList)
    }
    
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
        CellListFilterSettingsView(settings: $settings)
        .navigationTitle("Filter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    self.settingsBound = settings
                    self.close()
                } label: {
                    Text("Apply")
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

enum CellListFilterCustomOptions: String, CaseIterable, Identifiable {
    case all, custom
    
    var id: Self { self }
}

enum CellListFilterPredefinedOptions: String, CaseIterable, Identifiable {
    case all, predefined, custom
    
    var id: Self { self }
}



private struct CellListFilterSettingsView: View {
    
    @Binding var settings: CellListFilterSettings
    
    var body: some View {
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
            Section(header: Text("Data")) {
                Picker("Display", selection: $settings.timeFrame) {
                    Text("Live").tag(PacketFilterTimeFrame.live)
                    Text("Recorded").tag(PacketFilterTimeFrame.past)
                }
                if settings.timeFrame == .past {
                    DatePicker("Day", selection: $settings.date, in: ...Date(), displayedComponents: [.date])
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
