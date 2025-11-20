//
//  SysdiagnoseDetailsView.swift
//  CellGuard
//
//  Created by mp on 30.08.25.
//

import SwiftUI

struct SysdiagnoseDetailsView: View {
    let sysdiagnose: Sysdiagnose

    var body: some View {
        List {
            Section(header: Text("Metadata")) {
                DetailsRow("Imported", date: sysdiagnose.imported)
                DetailsRow("Captured", date: sysdiagnose.endTimeRef)
                DetailsRow("File", sysdiagnose.filename ?? "", multiLine: true)
                DetailsRow("Archive Identifier", sysdiagnose.archiveIdentifier ?? "", multiLine: true)
                DetailsRow("Source Identifier", sysdiagnose.sourceIdentifier ?? "", multiLine: true)
                DetailsRow("Baseband Chipset", sysdiagnose.basebandChipset ?? "")
                DetailsRow("iOS Build Version", sysdiagnose.productBuildVersion ?? "")
            }
            Section(header: Text("High Volume Log Entries"), footer: Text("The log section High Volume stores log entries which occur with a high frequency. The start time shows the category's first entry present in the system diagnose.")) {
                DetailsRow("Size Limit", ByteCountFormatter().string(fromByteCount: sysdiagnose.highVolumeSizeLimit))
                DetailsRow("Start Time", date: sysdiagnose.highVolumeTime)
            }
            Section(header: Text("Persist Log Entries"), footer: Text("The log section Persist stores log entries which occur with a low frequency. The start time shows the category's first entry present in the system diagnose.")) {
                DetailsRow("Size Limit", ByteCountFormatter().string(fromByteCount: sysdiagnose.persistSizeLimit))
                DetailsRow("Start Time", date: sysdiagnose.persistTime)
            }
            Section(header: Text("Imported Objects")) {
                DetailsRow("Packets", sysdiagnose.packetCount)
                DetailsRow("Cells", sysdiagnose.cellCount)
                DetailsRow("Connectivity Events", sysdiagnose.connectivityEventCount)
            }
        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("System Diagnose")
    }
}
