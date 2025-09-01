import SwiftUI

/// Friendlier, explanatory session report.
/// - Score computed vs **target** (norm-based by default)
/// - Shows "Starting point" (personal baseline) and "Target"
/// - Plain-language explainer for M/L sway and score
struct ReportView: View {
    @StateObject private var sessions = SessionSummaryStore.shared
    @StateObject private var baselineStore = BaselineStore.shared

    private var latest: SessionSummary? { sessions.sessions.last }
    private var starting: Baseline?     { baselineStore.baseline }   // user’s saved baseline (starting point)
    private var target: Baseline        { baselineStore.target }     // goal values (norms/ramped/personal)

    var body: some View {
        List {
            // MARK: Latest session card
            Section {
                if let s = latest {
                    LatestCard(session: s, target: target, starting: starting)
                } else {
                    Text("No walk sessions yet. Start a walk to see your first report.")
                        .foregroundStyle(.secondary)
                }
            } header: { Text("Latest Session") }

            // MARK: Recent sessions (Date / Score)
            Section {
                if sessions.sessions.isEmpty {
                    Text("No data yet. Start a walk to see your sessions here.")
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Text("Date").font(.footnote).foregroundStyle(.secondary)
                        Spacer()
                        Text("Score").font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 2)

                    ForEach(sessions.sessions.reversed()) { s in
                        HStack {
                            Text(s.dateFormatted)
                            Spacer()
                            Text("\(score(for: s, vs: target))")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(scoreColor(for: s, vs: target))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(s.dateFormatted), score \(score(for: s, vs: target))")
                    }
                }
            } header: { Text("Recent Sessions") }

            // MARK: Starting point (personal) and Target (goal)
            if let b = starting {
                Section {
                    metricsBlock(title: "Starting point",
                                 avg: b.avgStepTime,
                                 cv:  b.cvStepTime,
                                 sway: b.mlSwayRMS,
                                 foot: "Saved from your calibration. We track progress relative to this.")
                }
            }

            Section {
                let t = target
                metricsBlock(title: "Target",
                             avg: t.avgStepTime,
                             cv:  t.cvStepTime,
                             sway: t.mlSwayRMS,
                             foot: targetFootnote)
            }

            // Optional: jump to detailed trends dashboard
            Section {
                NavigationLink("View detailed trends") {
                    GaitProgressView(
                        sessions: sessions.sessions,
                        baselineAsym: starting?.asymStepTimePct,
                        baselineMLSway: starting?.mlSwayRMS,
                        baselineDate: starting?.date,
                        orientationIsGood: UserSettingsStore.shared.orientationQuality?.isGood ?? true
                    )
                }
            }

            // MARK: What the numbers mean
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Score (0–100)").font(.headline)
                    Text("Higher is steadier, more consistent walking. The score combines:")
                    bullet("Rhythm: how even your step timing is (CV step time).")
                    bullet("Stability: how much you sway side-to-side (M/L sway).")
                    bullet("Cadence relative to your usual pace.")

                    Text("Side-to-side (M/L) sway").font(.headline).padding(.top, 6)
                    Text("“M/L” means medial–lateral (left–right). RMS is a statistical average; lower values generally indicate better control.")

                    Text("CV step time").font(.headline).padding(.top, 6)
                    Text("The coefficient of variation of step time. Lower % means your steps are more evenly timed.")
                }
            } header: { Text("What the numbers mean") }
        }
        // Mint container look
        .scrollContentBackground(.hidden)
        .background(GCTheme.background.ignoresSafeArea())
        .listStyle(.insetGrouped)
        .listRowBackground(GCTheme.background.opacity(0.55))
        // Title lives here if this view is sometimes pushed elsewhere; in the tab, your AppTabView already sets it.
        .navigationTitle("Report")
    }

    // MARK: - UI helpers

    private var targetFootnote: String {
        switch baselineStore.targetPolicy {
        case .norms:
            return "Typical values for your age group."
        case .ramped:
            return "Gradually progressing from your starting point toward typical values."
        case .personal:
            return "Your personal baseline (no change)."
        }
    }

    private func metricsBlock(title: String, avg: Double, cv: Double, sway: Double, foot: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            metricRow(title: "Avg step time", value: String(format: "%.2f s", avg),
                      footnote: "Average time between steps.")
            metricRow(title: "CV step time", value: String(format: "%.1f%%", cv * 100),
                      footnote: "Step-to-step timing variability (lower is steadier).")
            metricRow(title: "Side-to-side (M/L) sway, RMS (g)", value: String(format: "%.3f g", sway),
                      footnote: "How much you sway left–right while walking.")
            Text(foot).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func metricRow(title: String, value: String, footnote: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(value).foregroundStyle(.secondary).monospacedDigit()
            }
            Text(footnote).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•")
            Text(text)
        }
    }
}

// MARK: - Latest Session Card

private struct LatestCard: View {
    let session: SessionSummary
    let target: Baseline
    let starting: Baseline?

    var scoreValue: Int { score(for: session, vs: target) }
    var scoreText: String { "\(scoreValue)/100" }
    var scoreInfo: (title: String, color: Color) {
        let c = scoreColor(for: session, vs: target)
        let title: String
        switch scoreValue {
        case 80...:    title = "Great"
        case 60..<80:  title = "Good"
        default:       title = "Caution"
        }
        return (title, c)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(scoreText).font(.title2.bold()).monospacedDigit()
                    Spacer()
                    Text(scoreInfo.title)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(scoreInfo.color.opacity(0.12), in: Capsule())
                        .foregroundStyle(scoreInfo.color)
                        .font(.subheadline.weight(.semibold))
                        .accessibilityHidden(true)
                }
                ProgressView(value: Double(scoreValue), total: 100).tint(scoreInfo.color)
            }

            Text(insight(for: session, vs: target, starting: starting))
                .foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading) {
                    Text("Steps").font(.footnote).foregroundStyle(.secondary)
                    Text("\(session.steps)").monospacedDigit()
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("Cadence (spm)").font(.footnote).foregroundStyle(.secondary)
                    Text(String(format: "%.1f", session.cadenceSPM)).monospacedDigit()
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("Side-to-side sway (g)").font(.footnote).foregroundStyle(.secondary)
                    Text(String(format: "%.3f", session.mlSwayRMS)).monospacedDigit()
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Score + Insight (vs target)

private func score(for s: SessionSummary, vs target: Baseline) -> Int {
    let cvRel   = clamp(target.cvStepTime  > 0 ? s.cvStepTime / target.cvStepTime  : 1, 0.5, 2.0)
    let swayRel = clamp(target.mlSwayRMS   > 0 ? s.mlSwayRMS  / target.mlSwayRMS   : 1, 0.5, 2.0)
    let expectedCad = max(30, min(150, 60.0 / max(target.avgStepTime, 0.2)))
    let cadRel  = clamp(abs(s.cadenceSPM - expectedCad) / 20.0, 0.0, 1.5) // 0=spot-on, 1≈20 spm away

    let wCV = 0.45, wSW = 0.45, wCA = 0.10
    let pCV = clamp((cvRel  - 1) / 1.0, 0, 1)
    let pSW = clamp((swayRel - 1) / 1.0, 0, 1)
    let pCA = cadRel

    let penalty = (wCV * pCV) + (wSW * pSW) + (wCA * pCA)
    let raw = 100.0 * (1.0 - penalty)

    let clamped = max(0.0, min(100.0, raw.rounded()))
    return Int(clamped)
}

private func scoreColor(for s: SessionSummary, vs target: Baseline) -> Color {
    let v = score(for: s, vs: target)
    switch v {
    case 80...:    return .green
    case 60..<80:  return .orange
    default:       return .red
    }
}

private func insight(for s: SessionSummary, vs target: Baseline, starting: Baseline?) -> String {
    let swayUp   = s.mlSwayRMS  > target.mlSwayRMS * 1.10
    let cvUp     = s.cvStepTime > target.cvStepTime * 1.10

    if swayUp && cvUp {
        return "More side-to-side sway and less even step timing than your target."
    } else if swayUp {
        return "More side-to-side sway than your target."
    } else if cvUp {
        return "Step timing is less even than your target."
    } else {
        if let b = starting {
            let betterSway = s.mlSwayRMS  < b.mlSwayRMS * 0.95
            let betterCV   = s.cvStepTime < b.cvStepTime  * 0.95
            if betterSway || betterCV {
                return "Improving vs your starting point—nice work!"
            }
        }
        return "Close to your target—keep it up."
    }
}

private func clamp<T: Comparable>(_ v: T, _ a: T, _ b: T) -> T { min(max(v, a), b) }

// MARK: - Convenience

private extension SessionSummary {
    var dateFormatted: String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: self.date)
    }
}

