//
//  DebugAddCellView.swift
//  CellGuard
//
//  Created by Lukas Arnold on 26.08.25.
//

import SwiftUI

private enum AlertType: Identifiable {
    case success
    case error(String)

    var id: String {
        switch self {
        case .success:
            return "success"
        case let .error(error):
            return "error - \(error)"
        }
    }
}

struct DebugAddCellView: View {
    @State var simSlot: Int? = 1
    @State var technology: ALSTechnology = .LTE
    @State var country: Int?
    @State var network: Int?
    @State var area: Int?
    @State var cellId: Int?

    @State var frequency: Int?
    @State var band: Int?
    @State var bandwidth: Int?
    @State var deploymentType: Int?

    @State var collected = Date()

    @State var verify = false

    @State private var alert: AlertType?

    var body: some View {
        List {
            Section(header: Text("Mandatory")) {
                Picker("SIM Slot", selection: $simSlot) {
                    Text("None").tag(nil as Int?)
                    Text("1").tag(1)
                    Text("2").tag(2)
                }
                Picker("Technology", selection: $technology) {
                    ForEach(ALSTechnology.allCases) { Text($0.rawValue).tag($0) }
                }
                LabelNumberField("Country", "MCC", $country)
                LabelNumberField("Network", "MNC", $network)
                LabelNumberField("Area", "LAC or TAC", $area)
                LabelNumberField("Cell", "Cell ID", $cellId)
            }

            Section(header: Text("Optional")) {
                LabelNumberField("Frequency", "(U/E/NR)ARFCN", $frequency)
                LabelNumberField("Band", "Number", $band)
                LabelNumberField("Bandwidth", "in MHz", $bandwidth)
                LabelNumberField("Deployment", "iOS Type", $deploymentType)
            }

            Section(header: Text("Collection Timestamp")) {
                DatePicker("Collected Timestamp", selection: $collected, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
            }

            Section {
                Toggle("Perform Verification", isOn: $verify)
                Button("Insert Cell") {
                    Task {
                        await insertCell()
                    }
                }
            }
        }
        .navigationTitle("Laboratory")
        .listStyle(.insetGrouped)
        .alert(item: $alert) { type in
            switch type {
            case .success:
                return Alert(title: Text("Success"), message: Text("Successfully inserted the cell"))
            case .error(let error):
                return Alert(title: Text("Error"), message: Text(error))
            }
        }
    }

    func insertCell() async {
        let verify = self .verify
        var props = CCTCellProperties()

        // TODO: Show an error if a value is out of its intended range
        // We don't implement this feature as of now as this view is only intended to be used for internal testing.
        if let simSlot = simSlot {
            props.simSlotID = UInt8(clamping: simSlot)
        }
        props.technology = technology
        if let country = country,
           let network = network,
           let area = area,
           let cellId = cellId {
            props.mcc = Int32(clamping: country)
            props.network = Int32(clamping: network)
            props.area = Int32(clamping: area)
            props.cellId = Int64(clamping: cellId)
        } else {
            self.alert = .error("Please fill all mandatory properties")
            return
        }
        if let frequency = frequency {
            props.frequency = Int32(clamping: frequency)
        }
        if let band = band {
            props.band = Int32(clamping: band)
        }
        if let bandwidth = bandwidth {
            props.bandwidth = Int32(clamping: bandwidth)
        }
        if let deploymentType = deploymentType {
            props.deploymentType = Int32(clamping: deploymentType)
        }
        props.timestamp = collected

        do {
            try await Task.detached {
                try PersistenceController
                    .basedOnEnvironment()
                    .importSingleTweakCell(cellProperties: props, verify: verify)
            }.value
            self.alert = .success
        } catch {
            self.alert = .error(error.localizedDescription)
        }
    }
}

#Preview {
    DebugAddCellView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
