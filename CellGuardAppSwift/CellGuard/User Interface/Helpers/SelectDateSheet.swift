//
//  DateSheets.swift
//  CellGuard
//
//  Created by Lukas Arnold on 29.08.25.
//

import SwiftUI

struct SelectDateSheet: View {
    var disableOnInfiniteRange = true

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Binding var timeFrame: FilterTimeFrame
    @Binding var date: Date
    @Binding var sheetRange: ClosedRange<Date>

    var body: some View {
        VStack {
            CompactDateSheet(timeFrame: $timeFrame, date: $date, sheetRange: $sheetRange)
                .presentationDetents([.height(horizontalSizeClass == .compact ? 400 : 500)])
        }
        .disabled(sheetRange.lowerBound == Date.distantPast && sheetRange.upperBound == Date.distantFuture)
    }
}

enum FilterTimeFrame: String, CaseIterable, Identifiable {
    case live, pastDay, pastDays
    var id: Self { self }
}

private struct CompactDateSheet: View {

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Binding var timeFrame: FilterTimeFrame
    @Binding var date: Date
    @Binding var sheetRange: ClosedRange<Date>

    var body: some View {
        // We're using a uniform height for the DatePicker and the sheet
        // See: https://stackoverflow.com/a/75544690
        // We're adding a padding to fix a UICalendarView layout constraint warning
        // See: https://stackoverflow.com/a/77669538
        DatePicker("Cell Date", selection: dateBinding, in: sheetRange, displayedComponents: [.date])
            .datePickerStyle(.graphical)
            .frame(
                maxHeight: horizontalSizeClass == .compact ? 400 : 500,
            )
            .padding()
    }

    var dateBinding: Binding<Date> {
        Binding {
            date
        } set: { newDate in
            let dateInBounds = newDate > sheetRange.upperBound ? sheetRange.upperBound : newDate
            let startOfDate: Date = Calendar.current.startOfDay(for: dateInBounds)
            let startOfToday = Calendar.current.startOfDay(for: Date())

            timeFrame = startOfToday == startOfDate ? .live : .pastDay
            date = dateInBounds
        }
    }
}

#Preview {
    // DateSheets()
}
