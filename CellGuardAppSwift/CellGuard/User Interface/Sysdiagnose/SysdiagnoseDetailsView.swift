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
                DetailsRow("End Time", date: sysdiagnose.endTimeRef)
                DetailsRow("Filename", sysdiagnose.filename ?? "")
                DetailsRow("Archive Identifier", sysdiagnose.archiveIdentifier ?? "")
                DetailsRow("Source Identifier", sysdiagnose.sourceIdentifier ?? "")
                DetailsRow("Baseband Chipset", sysdiagnose.basebandChipset ?? "")
                DetailsRow("iOS Build Version", sysdiagnose.productBuildVersion ?? "")
                DetailsRow("High Volume Size Limit", sysdiagnose.highVolumeSizeLimit)
                DetailsRow("High Volume Time", date: sysdiagnose.highVolumeTime)
                DetailsRow("Persist Size Limit", sysdiagnose.persistSizeLimit)
                DetailsRow("Persist Time", date: sysdiagnose.persistTime)
            }
            Section(header: Text("Imported Objects")) {
                DetailsRow("Packets", sysdiagnose.packetCount)
                DetailsRow("Cells", sysdiagnose.cellCount)
                DetailsRow("Connectivity Events", sysdiagnose.connectivityEventCount)
            }
        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Sysdiagnose")
    }
}
