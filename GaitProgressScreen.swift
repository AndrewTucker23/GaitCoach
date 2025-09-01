import SwiftUI

struct GaitProgressScreen: View {
    @StateObject private var sessions = SessionSummaryStore.shared
    @StateObject private var baseline = BaselineStore.shared
    @StateObject private var settings = UserSettingsStore.shared

    var body: some View {
        GaitProgressView(
            sessions: sessions.sessions,                            // <- live store data
            baselineAsym: baseline.baseline?.asymStepTimePct,
            baselineMLSway: baseline.baseline?.mlSwayRMS,
            baselineDate: baseline.baseline?.date,
            orientationIsGood: settings.orientationQuality?.isGood ?? true
        )
    }
}

#Preview { GaitProgressScreen() }

