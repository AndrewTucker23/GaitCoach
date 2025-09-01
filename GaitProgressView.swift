import SwiftUI

private let darkGreen = Color(red: 39/255, green: 77/255, blue: 67/255)

// MARK: - Public dashboard
struct GaitProgressView: View {
    // Inputs
    let sessions: [SessionSummary]
    let baselineAsym: Double?
    let baselineMLSway: Double?
    let baselineDate: Date?
    let orientationIsGood: Bool

    // Config
    private let lookback = 10
    private let driftFactor = 1.30
    private let baselineStaleDays = 30

    init(
        sessions: [SessionSummary],
        baselineAsym: Double? = nil,
        baselineMLSway: Double? = nil,
        baselineDate: Date? = nil,
        orientationIsGood: Bool = true
    ) {
        self.sessions = sessions
        self.baselineAsym = baselineAsym
        self.baselineMLSway = baselineMLSway
        self.baselineDate = baselineDate
        self.orientationIsGood = orientationIsGood
    }

    // Derived
    private var recent: [SessionSummary] {
        sessions.sorted { $0.date > $1.date }.prefix(lookback).map { $0 }
    }
    private var latest: SessionSummary? { recent.first }

    private var asymSeries: [Double] { recent.map { $0.asymStepTimePct } }
    private var mlSeries:   [Double] { recent.map { $0.mlSwayRMS } }
    private var cadSeries:  [Double] { recent.map { $0.cadenceSPM } }

    private var baselineIsStale: Bool {
        guard let d = baselineDate else { return false }
        return (Calendar.current.dateComponents([.day], from: d, to: Date()).day ?? 0) > baselineStaleDays
    }

    private var driftDetected: Bool {
        guard let bAsym = baselineAsym, let bML = baselineMLSway,
              !asymSeries.isEmpty, !mlSeries.isEmpty else { return false }
        let medAsym = median(asymSeries.suffix(5))
        let medML   = median(mlSeries.suffix(5))
        return (medAsym >= bAsym * driftFactor) || (medML >= bML * driftFactor)
    }

    private var shouldNudge: Bool { (!orientationIsGood) || baselineIsStale || driftDetected }

    var body: some View {
        NavigationStack {
            List {
                // Nudge banner
                if shouldNudge {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Re-calibration recommended", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.headline)

                            nudgeReasons

                            NavigationLink {
                                CalibrationView()
                            } label: {
                                Text("Recalibrate now")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(darkGreen, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Today vs Baseline
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Today vs Baseline").font(.headline)
                            Spacer()
                            if let d = baselineDate {
                                Text("Baseline \(d.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }

                        HStack(spacing: 24) {
                            deltaBlock(
                                title: "Asymmetry",
                                unit: "%",
                                today: latest?.asymStepTimePct,
                                baseline: baselineAsym
                            )
                            deltaBlock(
                                title: "M/L sway",
                                unit: "g",
                                today: latest?.mlSwayRMS,
                                baseline: baselineMLSway
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }

                // Trends
                Section {
                    VStack(spacing: 12) {
                        trendRow(title: "Asymmetry (%)",  values: asymSeries, target: baselineAsym, decimals: 1)
                        trendRow(title: "M/L sway (g)",   values: mlSeries,   target: baselineMLSway, decimals: 3)
                        trendRow(title: "Cadence (spm)",  values: cadSeries,  target: nil,            decimals: 0)
                    }
                } header: {
                    Text("TRENDS (LAST \(recent.count))")
                }

                // History list (compact)
                if !recent.isEmpty {
                    Section {
                        ForEach(recent) { s in
                            HStack {
                                Text(s.date, style: .date)
                                Spacer()
                                Text(String(format: "Asym %.1f%%", s.asymStepTimePct)).monospacedDigit()
                                Spacer(minLength: 6)
                                Text(String(format: "ML %.3f g", s.mlSwayRMS)).monospacedDigit().foregroundStyle(.secondary)
                                Spacer(minLength: 6)
                                Text(String(format: "%.0f spm", s.cadenceSPM)).monospacedDigit().foregroundStyle(.secondary)
                            }
                            .font(.footnote)
                        }
                    } header: { Text("RECENT SESSIONS") }
                }
            }
            .gcBackground()
            .listStyle(.insetGrouped)
            .listRowBackground(Color.white)   // explicit type to avoid generic inference issues
            .navigationTitle("Progress")
        }
    }

    // MARK: - Rows / Cards

    @ViewBuilder
    private var nudgeReasons: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !orientationIsGood {
                Label("Pocket orientation quality is low", systemImage: "xmark.circle")
                    .foregroundStyle(.secondary)
            }
            if baselineIsStale {
                Label("Baseline looks old — consider refreshing", systemImage: "calendar")
                    .foregroundStyle(.secondary)
            }
            if driftDetected {
                Label("Recent walks drifted from baseline", systemImage: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.footnote)
    }

    private func deltaBlock(title: String, unit: String, today: Double?, baseline: Double?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline)
            if let t = today, let b = baseline {
                let diff = t - b
                let arrow = diff >= 0 ? "arrow.up" : "arrow.down"
                let color: Color = (title.contains("Asym") ? (diff >= 0 ? .red : .green)
                                   : title.contains("sway") ? (diff >= 0 ? .red : .green)
                                   : .secondary)
                HStack(spacing: 6) {
                    Image(systemName: arrow).foregroundStyle(color)
                    Text(String(format: (unit == "%") ? "%.1f → %.1f" : "%.3f → %.3f", b, t))
                        .monospacedDigit()
                }
                .foregroundStyle(color)
            } else if let t = today {
                Text(String(format: unit == "%" ? "%.1f" : "%.3f", t))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
    }

    private func trendRow(title: String, values: [Double], target: Double?, decimals: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                if let last = values.last {
                    Text(format(last, decimals))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            LineSparkline(values: values, target: target)
                .frame(height: 46)
        }
    }

    // MARK: - Helpers

    private func median(_ slice: ArraySlice<Double>) -> Double {
        let a = Array(slice).sorted()
        guard !a.isEmpty else { return 0 }
        let mid = a.count / 2
        return (a.count % 2 == 0) ? (a[mid - 1] + a[mid]) / 2 : a[mid]
    }

    private func format(_ x: Double, _ decimals: Int) -> String {
        switch decimals {
        case 0:  return String(format: "%.0f", x)
        case 1:  return String(format: "%.1f", x)
        case 2:  return String(format: "%.2f", x)
        default: return String(format: "%.3f", x)
        }
    }
}

// MARK: - Sparkline

private struct LineSparkline: View {
    let values: [Double]
    let target: Double?

    private var normalized: [CGFloat] {
        guard values.count > 1 else { return [] }
        let lo = values.min() ?? 0
        let hi = values.max() ?? 1
        let span = max(hi - lo, 1e-6)
        return values.map { CGFloat(($0 - lo) / span) }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                if let t = target, let lo = values.min(), let hi = values.max(), hi > lo {
                    let ny = 1 - CGFloat((t - lo) / (hi - lo)).clamped(to: 0...1)
                    Path { p in
                        let Y = ny * geo.size.height
                        p.move(to: .init(x: 0, y: Y))
                        p.addLine(to: .init(x: geo.size.width, y: Y))
                    }
                    .stroke(Color.secondary.opacity(0.4),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }

                Path { p in
                    guard normalized.count > 1 else { return }
                    let stepX = geo.size.width / CGFloat(max(1, normalized.count - 1))
                    for (i, ny) in normalized.enumerated() {
                        let x = CGFloat(i) * stepX
                        let y = (1 - ny) * geo.size.height
                        if i == 0 { p.move(to: .init(x: x, y: y)) }
                        else { p.addLine(to: .init(x: x, y: y)) }
                    }
                }
                .stroke(Color.accentColor, lineWidth: 2)

                if let last = normalized.last {
                    let x = geo.size.width
                    let y = (1 - last) * geo.size.height
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                        .position(x: x, y: y)
                }
            }
        }
    }
}

// MARK: - Small util

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview (uses demo data)

#Preview {
    let demo: [SessionSummary] = (0..<10).map { i in
        SessionSummary(
            id: UUID(),
            date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
            steps: Int.random(in: 400...1500),
            cadenceSPM: Double.random(in: 80...120),
            mlSwayRMS: Double.random(in: 0.04...0.12),
            symmetryScore: Int.random(in: 60...95),
            tags: [],
            avgStepTime: Double.random(in: 0.5...0.8),
            cvStepTime: Double.random(in: 0.04...0.14),
            asymStepTimePct: Double.random(in: 5...15)
        )
    }
    return GaitProgressView(
        sessions: demo,
        baselineAsym: 8.0,
        baselineMLSway: 0.06,
        baselineDate: Calendar.current.date(byAdding: .day, value: -20, to: Date())!,
        orientationIsGood: true
    )
}

