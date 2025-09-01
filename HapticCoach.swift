import Foundation
import UIKit

/// Simple haptic coach for real-time asymmetry nudges.
/// Uses impact/notification generators (battery-friendly vs CoreHaptics).
final class HapticCoach {
    static let shared = HapticCoach()
    private init() {}

    // Rate limiting
    private var lastNudge: Date?
    private let minGapSeconds: TimeInterval = 12

    // Basic guards
    private let minCadence = 55.0   // ignore very slow / idle
    private let maxCadence = 170.0  // ignore running

    // Thresholds (tweak as you learn)
    private let cautionAsym: Double = 7.0   // %
    private let highAsym: Double = 12.0     // %

    func considerNudge(asymPct: Double, cadenceSPM: Double, enabled: Bool) {
        guard enabled else { return }
        guard cadenceSPM >= minCadence, cadenceSPM <= maxCadence else { return }

        // Rate limit
        let now = Date()
        if let last = lastNudge, now.timeIntervalSince(last) < minGapSeconds { return }

        // Decide pattern
        if asymPct >= highAsym {
            notify(.warning)
        } else if asymPct >= cautionAsym {
            tapDouble()
        } else {
            return
        }
        lastNudge = now
    }

    // MARK: - Patterns

    private func tapDouble() {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.prepare()
        gen.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            gen.impactOccurred()
        }
    }

    private func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(type)
    }
}

