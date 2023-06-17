//
//  KeyValueListRow.swift
//  CellGuard
//
//  Created by Lukas Arnold on 17.06.23.
//

import SwiftUI

struct KeyValueListRow: View {
    let key: String
    let value: String
    
    var body: some View {
        HStack {
            Text(key)
                .multilineTextAlignment(.leading)
            Spacer()
            Text(value)
                .foregroundColor(.gray)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct KeyValueListRow_Previews: PreviewProvider {
    static var previews: some View {
        List {
            KeyValueListRow(key: "Hello", value: "Test")
        }
    }
}
