import SwiftUI
import SafariServices

struct TodayView: View {
    // Data singletons
    @StateObject private var plan      = ExercisePlanStore.shared
    @StateObject private var sessions  = SessionSummaryStore.shared
    @StateObject private var baseline  = BaselineStore.shared
    @StateObject private var ramp      = AutoRampEngine.shared   // reads auto progress

    // UI state
    @State private var ringProgress: Double = 0.0
    @State private var playing: PlannedExercise?
    @State private var tutorial: TutorialLink?
    @State private var noVideoAlert = false

    /// We only show/compute against the first 3 items
    private var visibleToday: [PlannedExercise] { Array(plan.today.prefix(3)) }

    var body: some View {
        NavigationStack {
            List {
                goalProgressSection        // colored, read-only meter
                progressSection
                todaySection(items: visibleToday)
            }
            // App-wide styling (local)
            .scrollContentBackground(.hidden)
            .background(GCTheme.background.ignoresSafeArea())
            .listStyle(.insetGrouped)
            .listRowBackground(GCTheme.background.opacity(0.55))
            .listSectionSpacing(12)
            .navigationTitle("Today")
        }
        .onAppear {
            ensurePlanForToday()
            updateRing(animated: false)
        }
        // Observe published array the safe way
        .onReceive(plan.$today) { _ in
            updateRing(animated: true)
        }
        // Timer/player sheet
        .sheet(item: $playing) { ex in
            ExercisePlayerView(exercise: ex.exercise)
        }
        // Tutorial sheet
        .sheet(item: $tutorial) { link in
            SafariSheet(url: link.url).ignoresSafeArea()
        }
        .alert("No tutorial video found", isPresented: $noVideoAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We’ll add a short, professional demo for this exercise.")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var goalProgressSection: some View {
        Section {
            let isPersonal = (baseline.targetPolicy == .personal)
            let fraction = isPersonal ? ramp.baselineConsistency : ramp.towardTypical
            GoalProgressCard(
                title: isPersonal ? "Consistency to your baseline" : "Progress toward typical",
                fraction: fraction,
                subtitle: isPersonal
                    ? "How closely your recent walking matches your personal baseline."
                    : "Progress adjusts automatically based on your recent walking scores."
            )
        }
    }

    private var progressSection: some View {
        Section {
            HStack {
                Spacer()
                ProgressRingView(progress: ringProgress, size: 140, line: 12)
                    .accessibilityLabel("Today's Plan Progress")
                    .accessibilityValue("\(Int(ringProgress * 100)) percent complete")
                Spacer()
            }
            .listRowInsets(.init(top: 16, leading: 0, bottom: 16, trailing: 0))
        }
    }

    @ViewBuilder
    private func todaySection(items: [PlannedExercise]) -> some View {
        Section {
            if items.isEmpty {
                Text("We’ll suggest a few exercises based on your last walk.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    itemRow(item)
                }
            }
        } header: {
            Text("TODAY")
        }
    }

    private func itemRow(_ item: PlannedExercise) -> some View {
        PlanRow(
            item: item,
            toggle: {
                plan.toggleDone(item.id)
                updateRing(animated: true)
            },
            playTutorial: {
                if let url = TutorialRegistry.url(for: item.exercise) {
                    tutorial = .init(url: url)
                } else {
                    noVideoAlert = true
                }
            },
            startTimer: { playing = item }
        )
    }

    // MARK: - Logic

    private func ensurePlanForToday() {
        guard plan.today.isEmpty else { return }
        let patterns = patternsFromLast()
        plan.resetForToday()
        plan.generateFromPatterns(patterns)
    }

    private func patternsFromLast() -> [String] {
        guard let s = sessions.sessions.last else { return [] }
        return GaitPatternDetector().detect(
            asymPct: s.asymStepTimePct,
            mlRMS:   s.mlSwayRMS,
            cadenceSPM: s.cadenceSPM,
            cvStepTime: s.cvStepTime
        )
    }


    private func updateRing(animated: Bool) {
        let items = visibleToday
        let total = max(items.count, 1)
        let done  = items.filter { $0.isDone }.count
        let p = Double(done) / Double(total)
        if animated { withAnimation(.easeInOut(duration: 0.4)) { ringProgress = p } }
        else { ringProgress = p }
    }
}

// MARK: - Row

private struct PlanRow: View {
    let item: PlannedExercise
    var toggle: () -> Void
    var playTutorial: () -> Void
    var startTimer: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.exercise.name).font(.headline)
                Text(item.exercise.blurb)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text("\(item.minutes) min")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Button(action: playTutorial) {
                        Image(systemName: "play.circle").imageScale(.large)
                    }.buttonStyle(.plain)

                    Button(action: startTimer) {
                        Image(systemName: "clock").imageScale(.large)
                    }.buttonStyle(.plain)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: toggle)
        .padding(.vertical, 4)
    }
}

// MARK: - Progress Ring

private struct ProgressRingView: View {
    var progress: Double
    var size: CGFloat = 120
    var line: CGFloat = 10
    var color: Color = GCTheme.header

    var body: some View {
        ZStack {
            Circle().strokeBorder(.secondary.opacity(0.18), lineWidth: line)

            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text("\(Int(round(progress * 100)))%").font(.title2.bold()).monospacedDigit()
                Text("Today's Plan").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.4), value: progress)
    }
}

// MARK: - Tutorial helpers

private enum TutorialRegistry {
    static func url(for ex: ExerciseItem) -> URL? {
        let name = ex.name.lowercased()
        if name.contains("glute bridge") {
            return URL(string: "https://www.youtube.com/results?search_query=glute+bridge+exercise+tutorial")
        } else if name.contains("hip abduction") {
            return URL(string: "https://www.youtube.com/results?search_query=side+lying+hip+abduction+exercise")
        } else if name.contains("sit-to-stand") || name.contains("sit to stand") {
            return URL(string: "https://www.youtube.com/results?search_query=sit+to+stand+exercise+tempo")
        }
        return nil
    }
}

private struct TutorialLink: Identifiable {
    let id = UUID()
    let url: URL
}

private struct SafariSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

// MARK: - Goal Meter

private struct GoalProgressCard: View {
    let title: String
    let fraction: Double   // 0…1
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(round(fraction * 100)))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            GradientMeter(fraction: fraction)

            Text(statusText(for: fraction))
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(statusColor(for: fraction).opacity(0.15), in: Capsule())
                .foregroundStyle(statusColor(for: fraction))

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func statusText(for f: Double) -> String {
        switch f {
        case ..<0.2:  return "Starting out"
        case ..<0.6:  return "Improving"
        default:      return "On track"
        }
    }
    private func statusColor(for f: Double) -> Color {
        switch f {
        case ..<0.2:  return .red
        case ..<0.6:  return .orange
        default:      return .green
        }
    }
}

private struct GradientMeter: View {
    let fraction: Double
    var body: some View {
        GeometryReader { geo in
            let w = max(0, min(1, fraction)) * geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.secondary.opacity(0.18))
                Capsule()
                    .fill(LinearGradient(
                        colors: [.red, .orange, .yellow, .green],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: w)
            }
        }
        .frame(height: 18)
        .clipShape(Capsule())
    }
}

