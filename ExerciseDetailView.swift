import SwiftUI
import AVKit
import SafariServices
import Combine
import AudioToolbox

// MARK: - Detail Screen (video + interval timer)

struct ExerciseDetailView: View {
    let item: ExerciseItem

    @StateObject private var vm: ExerciseTimerVM

    init(item: ExerciseItem) {
        self.item = item
        _vm = StateObject(wrappedValue: ExerciseTimerVM(
            workSeconds: max(30, item.minutesDefault * 60),  // default work = item duration
            restSeconds: 45,
            rounds: 3
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                videoBlock
                Text(item.name).font(.title.bold())
                Text(item.blurb).foregroundStyle(.secondary)

                if !item.muscles.isEmpty {
                    Text("Targets: " + item.muscles.map { $0.uiName }.joined(separator: " • "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Divider().padding(.vertical, 4)

                timerBlock
            }
            .padding()
        }
        .navigationTitle("Tutorial")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Video

    @ViewBuilder
    private var videoBlock: some View {
        if let urlString = item.videoURL ?? VideoLibrary.urlString(for: item.name),
           let url = URL(string: urlString) {

            // If it's a direct media URL we can play inline with AVPlayer.
            if url.pathExtension.lowercased() == "mp4" || url.absoluteString.contains(".m3u8") {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // Fallback: open inside an in-app Safari sheet (great for YouTube/Vimeo pages)
                SafariLink(url: url)
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.12))
                VStack(spacing: 8) {
                    Image(systemName: "play.circle.fill").font(.system(size: 48))
                    Text("No tutorial available").foregroundStyle(.secondary)
                }
            }
            .frame(height: 200)
        }
    }

    // MARK: Timer

    private var timerBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Interval Timer").font(.headline)

            HStack(spacing: 16) {
                phaseBadge(vm.phase)
                Spacer()

                VStack(alignment: .trailing) {
                    Text(vm.timeString)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("Round \(min(vm.currentRound, vm.rounds))/\(vm.rounds)")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            ProgressView(value: vm.progress)
                .progressViewStyle(.linear)
                .tint(vm.phase == .work ? .green : .blue)

            HStack(spacing: 18) {
                Button(vm.isRunning ? "Pause" : "Start") { vm.startPause() }
                    .buttonStyle(.borderedProminent)
                Button("Reset") { vm.reset() }
                    .buttonStyle(.bordered)
                    .disabled(vm.isRunning)
                Button("Skip") { vm.skipPhase() }
                    .buttonStyle(.bordered)
            }

            // Config
            VStack(spacing: 10) {
                Stepper(value: $vm.workSeconds, in: 10...20*60, step: 10) {
                    HStack { Text("Work"); Spacer(); Text(vm.formatSeconds(vm.workSeconds)) }
                }
                Stepper(value: $vm.restSeconds, in: 0...5*60, step: 5) {
                    HStack { Text("Rest"); Spacer(); Text(vm.formatSeconds(vm.restSeconds)) }
                }
                Stepper(value: $vm.rounds, in: 1...10) {
                    HStack { Text("Rounds"); Spacer(); Text("\(vm.rounds)") }
                }
            }
            .disabled(vm.isRunning)
            .font(.subheadline)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func phaseBadge(_ p: ExerciseTimerVM.Phase) -> some View {
        let (txt, color, icon): (String, Color, String) = {
            switch p {
            case .idle:     return ("Ready", .secondary, "pause.circle")
            case .work:     return ("WORK", .green, "figure.strengthtraining.traditional")
            case .rest:     return ("REST", .blue, "bed.double")
            case .finished: return ("Done", .teal, "checkmark.seal.fill")
            }
        }()
        Label(txt, systemImage: icon)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

// MARK: - ViewModel

final class ExerciseTimerVM: ObservableObject {
    enum Phase { case idle, work, rest, finished }

    // Config
    @Published var workSeconds: Int
    @Published var restSeconds: Int
    @Published var rounds: Int

    // State
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var isRunning = false
    @Published private(set) var remaining = 0
    @Published private(set) var currentRound = 1

    private var timerC: AnyCancellable?

    init(workSeconds: Int, restSeconds: Int, rounds: Int) {
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.rounds = rounds
        self.remaining = workSeconds
    }

    var timeString: String { formatSeconds(remaining) }
    var progress: Double {
        switch phase {
        case .work:     return 1 - Double(remaining) / Double(max(1, workSeconds))
        case .rest:     return restSeconds == 0 ? 1 : 1 - Double(remaining) / Double(restSeconds)
        case .idle:     return 0
        case .finished: return 1
        }
    }

    func startPause() {
        isRunning.toggle()
        if isRunning {
            if phase == .idle || phase == .finished { startWorkRound(1) }
            startTimer()
        } else {
            timerC?.cancel(); timerC = nil
        }
    }

    func reset() {
        timerC?.cancel(); timerC = nil
        isRunning = false
        phase = .idle
        currentRound = 1
        remaining = workSeconds
    }

    func skipPhase() {
        guard isRunning else { return }
        remaining = 0
        tick() // will roll phase
    }

    // MARK: internals

    private func startTimer() {
        timerC?.cancel()
        timerC = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard isRunning else { return }
        guard remaining > 0 else {
            advancePhase()
            return
        }
        remaining -= 1
        if remaining == 3 || remaining == 2 || remaining == 1 { beep() }
    }

    private func advancePhase() {
        switch phase {
        case .work:
            if restSeconds > 0 {
                phase = .rest
                remaining = restSeconds
                beep()
            } else {
                // no rest, go straight to next round
                nextRoundOrFinish()
            }

        case .rest:
            nextRoundOrFinish()

        case .idle:
            startWorkRound(1)

        case .finished:
            isRunning = false
            timerC?.cancel(); timerC = nil
        }
    }

    private func nextRoundOrFinish() {
        if currentRound < rounds {
            startWorkRound(currentRound + 1)
        } else {
            phase = .finished
            isRunning = false
            timerC?.cancel(); timerC = nil
            beep()
        }
    }

    private func startWorkRound(_ round: Int) {
        currentRound = round
        phase = .work
        remaining = workSeconds
        beep()
    }

    func formatSeconds(_ s: Int) -> String {
        let m = s / 60, r = s % 60
        return String(format: "%02d:%02d", m, r)
    }

    private func beep() {
        AudioServicesPlaySystemSound(1057) // short beep
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Small Safari wrapper (for YouTube, etc.)

private struct SafariLink: View {
    let url: URL
    @State private var show = false

    var body: some View {
        Button {
            show = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.12))
                HStack(spacing: 12) {
                    Image(systemName: "play.rectangle.fill").font(.system(size: 28))
                    VStack(alignment: .leading) {
                        Text("Watch tutorial").font(.headline)
                        Text(url.host ?? url.absoluteString).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "safari").foregroundStyle(.secondary)
                }
                .padding()
            }
            .frame(height: 80)
        }
        .sheet(isPresented: $show) {
            SafariViewController(url: url)
                .ignoresSafeArea()
        }
    }
}

private struct SafariViewController: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    ExerciseDetailView(item: ExerciseItem(
        name: "Glute Bridge",
        blurb: "Drive through heels; ribs down; squeeze glutes.",
        minutesDefault: 3,
        systemImage: "figure.strengthtraining.traditional",
        videoURL: nil,
        muscles: [.gluteMax, .core]
    ))
}

