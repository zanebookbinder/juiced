import SwiftUI

@main
struct JuicedApp: App {
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup { ContentView() }
            .backgroundTask(.appRefresh(ChargeMonitor.refreshTaskID)) {
                await ChargeMonitor.shared.backgroundRefresh()
            }
            .onChange(of: phase) { _, newPhase in
                if newPhase == .background { ChargeMonitor.shared.scheduleRefresh() }
            }
    }
}
