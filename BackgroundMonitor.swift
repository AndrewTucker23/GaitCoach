import Foundation
import Combine

/// A tiny holder for “nudge” suggestions the UI can observe + rate limiting/snooze.
final class BackgroundMonitor: ObservableObject {
    static let shared = BackgroundMonitor()
    private init() {
        // load persisted state
        let d = UserDefaults.standard
        lastNudgeDate = d.object(forKey: Keys.lastNudgeDate) as? Date
        snoozeUntil   = d.object(forKey: Keys.snoozeUntil)   as? Date
    }

    // MARK: - Suggestion model

    struct Suggestion {
        let message: String
        let reasons: [String]
    }

    /// UI observes this; when it changes, the banner updates.
    @Published private(set) var suggestion: Suggestion?

    // MARK: - Rate-limit / Snooze (persisted)

    private enum Keys {
        static let lastNudgeDate = "gc.lastNudgeDate"
        static let snoozeUntil   = "gc.snoozeUntil"
    }

    private(set) var lastNudgeDate: Date? {
        didSet { UserDefaults.standard.set(lastNudgeDate, forKey: Keys.lastNudgeDate) }
    }

    private(set) var snoozeUntil: Date? {
        didSet { UserDefaults.standard.set(snoozeUntil, forKey: Keys.snoozeUntil) }
    }

    /// Check if we’re allowed to show a nudge now.
    /// Rules:
    ///  - at most 1/day
    ///  - not within 48h of the most recent calibration (baseline.date)
    ///  - not during an active snooze window
    func canNudge(baselineDate: Date?) -> Bool {
        let now = Date()

        if let snooze = snoozeUntil, now < snooze { return false }

        if let last = lastNudgeDate, now.timeIntervalSince(last) < 24*60*60 {
            return false
        }

        if let baseDate = baselineDate, now.timeIntervalSince(baseDate) < 48*60*60 {
            return false
        }

        return true
    }

    /// Mark that we emitted a nudge.
    func markNudged() { lastNudgeDate = Date() }

    /// Snooze for N days (used by “Not now”).
    func snooze(days: Int) {
        snoozeUntil = Calendar.current.date(byAdding: .day, value: days, to: Date())
        clear() // hide current banner
    }

    // MARK: - Suggestion control

    /// Call from background logic (e.g., MobilityWatcher) to surface a banner.
    func setSuggestion(message: String, reasons: [String]) {
        let s = Suggestion(message: message, reasons: reasons)
        if Thread.isMainThread {
            self.suggestion = s
        } else {
            DispatchQueue.main.async { self.suggestion = s }
        }
    }

    /// Clear the current suggestion (e.g., after user acts).
    func clear() {
        if Thread.isMainThread {
            self.suggestion = nil
        } else {
            DispatchQueue.main.async { self.suggestion = nil }
        }
    }
}

