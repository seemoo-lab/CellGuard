//
//  SysdiagnoseListView.swift
//  CellGuard
//
//  Created by mp on 31.08.25.
//

import CoreData
import Foundation
import SwiftUI
import OSLog
import NavigationBackport

struct SysdiagnoseListView: View {

    @State private var isShowingDateSheet = false
    @State private var sheetRange = Date.distantPast...Date.distantFuture

    @EnvironmentObject private var navigator: PathNavigator
    @EnvironmentObject private var settings: SysdiagnoseFilterSettings

    private func updateDateRange() {
        Task.detached {
            if let range = await PersistenceController.basedOnEnvironment().fetchSysdiagnoseDateRange() {
                await MainActor.run {
                    settings.showLatestData(range: range)
                    sheetRange = range
                }
            }
        }
    }

    var body: some View {
        FilteredSysdiagnoseView(settings: settings)
        .navigationTitle("System Diagnoses")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isShowingDateSheet = true
                } label: {
                    Image(systemName: settings.timeFrame == .pastDays ? "calendar.badge.clock" : "calendar")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    navigator.push(SummaryNavigationPath.sysdiagFilter)
                } label: {
                    Image(systemName: CGIcons.filter)
                }
            }
        }
        .sheet(isPresented: $isShowingDateSheet) {
            SelectDateSheet(timeFrame: $settings.timeFrame, date: $settings.date, sheetRange: $sheetRange)
                .onAppear { updateDateRange() }
        }
        .onAppear { updateDateRange() }
    }
}

private struct FilteredSysdiagnoseView: View {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: FilteredSysdiagnoseView.self)
    )

    private let settings: SysdiagnoseFilterSettings

    @FetchRequest
    private var sysdiagnoses: FetchedResults<Sysdiagnose>

    init(settings: SysdiagnoseFilterSettings) {
        self.settings = settings

        let sysdiagnoseRequest: NSFetchRequest<Sysdiagnose> = Sysdiagnose.fetchRequest()
        sysdiagnoseRequest.sortDescriptors = [NSSortDescriptor(key: "imported", ascending: false)]
        settings.applyTo(request: sysdiagnoseRequest)

        self._sysdiagnoses = FetchRequest(fetchRequest: sysdiagnoseRequest, animation: .easeOut)
    }

    var body: some View {
        if !sysdiagnoses.isEmpty {
            List(sysdiagnoses) { sysdiagnose in
                ListNavigationLink(value: NavObjectId(object: sysdiagnose)) {
                    SysdiagnoseCell(sysdiagnose: sysdiagnose, showArchiveIdentifier: true)
                }
            }
            .listStyle(.insetGrouped)
        } else {
            Text("No sysdiagnose match your query.")
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}

struct SysdiagnoseListView_Previews: PreviewProvider {
    static var previews: some View {
        @State var sysdiagnoseFilterSettings = SysdiagnoseFilterSettings()

        NBNavigationStack {
            SysdiagnoseListView()
                .cgNavigationDestinations(.sysdiagnoses)
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(sysdiagnoseFilterSettings)
    }
}
