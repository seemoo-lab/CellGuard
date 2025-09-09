//
//  SysdiagnoseCell.swift
//  CellGuard
//
//  Created by mp on 30.08.25.
//

import SwiftUI

struct SysdiagnoseCell: View {
    let sysdiagnose: Sysdiagnose
    let showArchiveIdentifier: Bool

    var body: some View {
        VStack {
            SysdiagnoseCellBody(sysdiagnose: sysdiagnose, showArchiveIdentifier: showArchiveIdentifier)
            SysdiagnoseCellFooter(sysdiagnose: sysdiagnose)
        }
    }
}

private struct SysdiagnoseCellBody: View {
    let sysdiagnose: Sysdiagnose
    let showArchiveIdentifier: Bool

    var body: some View {
        HStack {
            Text(showArchiveIdentifier ? sysdiagnose.archiveIdentifier ?? "" : "Sysdiagnose")
            Spacer()
        }
    }

}

private struct SysdiagnoseCellFooter: View {

    let sysdiagnose: Sysdiagnose

    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.gray)
            Spacer()
        }
    }

    var text: String {
        if let endTime = sysdiagnose.endTimeRef {
            return fullMediumDateTimeFormatter.string(from: endTime)
        } else if let imported = sysdiagnose.imported {
            return "Imported: \(fullMediumDateTimeFormatter.string(from: imported))"
        } else {
            return ""
        }
    }
}
