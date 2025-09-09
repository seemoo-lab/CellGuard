//
//  SysdiagnoseCell.swift
//  CellGuard
//
//  Created by mp on 30.08.25.
//

import SwiftUI

struct SysdiagnoseCell: View {
    let sysdiagnose: Sysdiagnose

    var body: some View {
        VStack {
            SysdiagnoseCellBody()
            SysdiagnoseCellFooter(sysdiagnose: sysdiagnose)
        }
    }
}

private struct SysdiagnoseCellBody: View {
    var body: some View {
        HStack {
            Text("Sysdiagnose")
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
