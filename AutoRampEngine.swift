// AutoRampEngine.swift
import Foundation          // ← needed for DispatchQueue
import Combine

final class AutoRampEngine: ObservableObject {
    static let shared = AutoRampEngine()

    @Published private(set) var towardTypical: Double = 0.0        // 0…1
    @Published private(set) var baselineConsistency: Double = 0.0  // 0…1

    private var bag = Set<AnyCancellable>()

    /// Wire once; safe to call repeatedly.
    func start() {
        guard bag.isEmpty else { return }

        // Recompute whenever sessions change…
        SessionSummaryStore.shared.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.recompute() }
            .store(in: &bag)

        // …or when baseline gets saved/cleared (affects personal comparison).
        BaselineStore.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.recompute() }
            .store(in: &bag)

        recompute()
    }

    private func recompute() {
        let recent = Array(SessionSummaryStore.shared.sessions.suffix(5))
        guard !recent.isEmpty else {
            towardTypical = 0
            baselineConsistency = 0
            BaselineStore.shared.rampFraction = 0
            return
        }

        // Score vs age-typical norms
        let norms = BaselineStore.shared.targetForNorms()
        let avgNorm = recent.map { Self.score(for: $0, vs: norms) }.average
        let normProgress = max(0, min(1, (avgNorm - 50.0) / 50.0)) // 50→0%, 100→100%
        towardTypical = normProgress
        BaselineStore.shared.rampFraction = normProgress   // so Settings shows same %

        // Score vs personal baseline (or norms if none saved yet)
        let start = BaselineStore.shared.baseline ?? norms
        let avgBase = recent.map { Self.score(for: $0, vs: start) }.average
        baselineConsistency = max(0, min(1, (avgBase - 50.0) / 50.0))
    }

    // MARK: - Scoring helper (0…100)
    private static func score(for s: SessionSummary, vs b: Baseline) -> Double {
        // Ratios relative to target/baseline; 1.0 is "at target"
        let rStep  = b.avgStepTime / max(s.avgStepTime, 0.0001)
        let rCV    = (b.cvStepTime + 0.0001) / max(s.cvStepTime, 0.0001)
        let rSway  = b.mlSwayRMS / max(s.mlSwayRMS, 0.0001)

        // Map each ratio to 0…1 (gentle curve), then average → 0…100
        let c1 = clamp01(scaledScore(rStep))
        let c2 = clamp01(scaledScore(rCV))
        let c3 = clamp01(scaledScore(rSway))
        return (c1 + c2 + c3) / 3.0 * 100.0
    }

    private static func scaledScore(_ r: Double) -> Double {
        // r >= 1 (worse than target) → ~1/r ; r < 1 (better) → > 0.5 with soft gain
        if r >= 1 { return 1.0 / r }
        return 1 - (1 - r) * 0.5
    }

    private static func clamp01(_ x: Double) -> Double { max(0, min(1, x)) }
}

private extension Array where Element == Double {
    var average: Double { isEmpty ? 0 : reduce(0, +) / Double(count) }
}

