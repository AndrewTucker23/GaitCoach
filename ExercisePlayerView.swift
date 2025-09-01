import SwiftUI
import AVFoundation
import AudioToolbox

private let darkGreen = Color(red: 39/255, green: 77/255, blue: 67/255) // #274D43

struct ExercisePlayerView: View, Identifiable {
    let id = UUID()
    let exercise: ExerciseItem

    init(exercise: ExerciseItem) { self.exercise = exercise }

    // Defaults
    @State private var sets = 3
    @State private var workSec = 30
    @State private var restSec = 20

    // Run state
    enum Phase: String { case idle, work, rest, done }
    @State private var currentSet = 1
    @State private var phase: Phase = .idle
    @State private var remaining = 0
    @State private var phaseTotal = 0
    @State private var timer: Timer?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 18) {
                    Capsule()
                        .fill(darkGreen.opacity(0.12))
                        .frame(height: 10)
                        .padding(.top, 8)

                    // Header
                    VStack(spacing: 6) {
                        Text(exercise.name)
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)

                        Text(exercise.blurb)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.top, 2)

                    // Timer + ring
                    ZStack {
                        let prog = phaseTotal > 0 ? 1 - Double(remaining) / Double(phaseTotal) : 0
                        PlayerRing(progress: prog, lineWidth: 14, color: darkGreen)
                            .frame(width: 160, height: 160)

                        VStack(spacing: 6) {
                            Text(phaseLabel).font(.headline)
                            Text(timeString(remaining))
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .minimumScaleFactor(0.8)
                            Text("Set \(min(currentSet, sets)) of \(sets)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)

                    // Counters
                    VStack(spacing: 12) {
                        CounterRow(
                            title: "Sets",
                            valueText: "\(sets)",
                            onMinus: { sets = max(1, sets - 1) },
                            onPlus:  { sets = min(10, sets + 1) }
                        )

                        CounterRow(
                            title: "Work",
                            valueText: "\(workSec)s",
                            onMinus: { workSec = max(10, workSec - 5) },
                            onPlus:  { workSec = min(120, workSec + 5) }
                        )

                        CounterRow(
                            title: "Rest",
                            valueText: "\(restSec)s",
                            onMinus: { restSec = max(10, restSec - 5) },
                            onPlus:  { restSec = min(120, restSec + 5) }
                        )
                    }
                    .padding(.horizontal, 6)

                    // CTA bar
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Button(phase == .idle || phase == .done ? "Start" : "Resume") { start() }
                                    .buttonStyle(.borderedProminent)
                                    .tint(darkGreen)          // #274D43 fill
                                    .foregroundStyle(.white)
                                    .disabled(phase == .work || phase == .rest)

                                Button("Pause") { pause() }
                                    .buttonStyle(.bordered)   // neutral/secondary outline
                                    .tint(.secondary)
                                    .disabled(!(phase == .work || phase == .rest))

                                Button("Reset") { reset() }
                                    .buttonStyle(.bordered)   // green outline (matches other screens)
                                    .tint(darkGreen)
                            }

                            // keep "Done" neutral
                            Button("Done") { dismiss() }
                                .buttonStyle(.bordered)
                                .tint(.secondary)
                    }
                    .padding(.bottom, 8)
                }
                .gcCard()
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .gcBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - Phase helpers
    private var phaseLabel: String {
        switch phase {
        case .idle: return "Ready"
        case .work: return "Work"
        case .rest: return "Rest"
        case .done: return "Completed"
        }
    }

    private func start() {
        if phase == .idle || phase == .done {
            currentSet = 1
            phase = .work
            remaining = workSec
            phaseTotal = workSec
            ping()
        } else if phase != .work && phase != .rest {
            phase = .work
            remaining = workSec
            phaseTotal = workSec
            ping()
        }
        schedule()
    }

    private func pause() { timer?.invalidate(); timer = nil }

    private func reset() {
        pause()
        withAnimation { phase = .idle; currentSet = 1; remaining = 0; phaseTotal = 0 }
    }

    private func schedule() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard remaining > 0 else { advancePhase(); return }
            remaining -= 1
        }
    }

    private func advancePhase() {
        if phase == .work {
            withAnimation { phase = .rest }
            remaining = restSec
            phaseTotal = restSec
            ping(); schedule()
        } else if phase == .rest {
            if currentSet < sets {
                currentSet += 1
                withAnimation { phase = .work }
                remaining = workSec
                phaseTotal = workSec
                ping(); schedule()
            } else {
                withAnimation { phase = .done }
                remaining = 0
                phaseTotal = 0
                ping(); pause()
            }
        }
    }

    private func timeString(_ s: Int) -> String { String(format: "%d:%02d", s/60, s%60) }

    private func ping() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(1104)
    }
}

// MARK: - Local ring (unique name to avoid clashes)
private struct PlayerRing: View {
    var progress: Double        // 0...1
    var lineWidth: CGFloat
    var color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(colors: [color, color.opacity(0.9), color], center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: progress)
        }
    }
}

// MARK: - UI Pieces (unchanged)
private struct CounterRow: View {
    let title: String
    let valueText: String
    var onMinus: () -> Void
    var onPlus:  () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold)) // larger + bolder
                .foregroundStyle(.primary)            // black in light, white in dark

            HStack(spacing: 10) {
                IconButton(system: "minus", action: onMinus)

                Text(valueText)
                    .font(.headline.monospacedDigit())
                    .frame(minWidth: 44, maxWidth: .infinity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                IconButton(system: "plus", action: onPlus)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.95))
            .clipShape(Capsule())
        }
    }

    private struct IconButton: View {
        let system: String
        var action: () -> Void
        var body: some View {
            Button(action: action) {
                Image(systemName: system)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(darkGreen)
                    .frame(width: 28, height: 28)
                    .background(darkGreen.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
}
