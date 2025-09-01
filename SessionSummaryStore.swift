import Foundation
import Combine

// MARK: - Model

struct SessionSummary: Identifiable, Codable {
    let id: UUID
    let date: Date
    let steps: Int
    let cadenceSPM: Double
    let mlSwayRMS: Double
    let symmetryScore: Int
    let tags: [String]
    let avgStepTime: Double
    let cvStepTime: Double
    let asymStepTimePct: Double
}

// MARK: - Store

final class SessionSummaryStore: ObservableObject {
    static let shared = SessionSummaryStore()

    @Published private(set) var sessions: [SessionSummary] = [] {
        didSet { persist() }
    }

    private let url: URL

    private init() {
        let fn = "GaitCoach.sessions.v1.json"
        url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fn)
        load()
    }

    // MARK: CRUD

    func add(_ s: SessionSummary) {
        sessions.append(s)
    }

    func deleteAll() {
        sessions.removeAll()
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: Persistence

    private func persist() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: url, options: [.atomic])
        } catch {
            // ignore file I/O errors
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        if let items = try? JSONDecoder().decode([SessionSummary].self, from: data) {
            sessions = items
        }
    }
}

// MARK: - Passive day upsert

extension SessionSummaryStore {

    /// Create or update a lightweight "passive" daily summary (aggregated from HealthKit).
    /// Keeps your `SessionSummary` immutable by replacing the struct when updating.
    func upsertPassiveDay(date: Date,
                          steps: Int,
                          walkingSpeed: Double?,
                          stepLength: Double?,
                          asymPct: Double?,
                          doubleSupportPct: Double?) {

        // Normalize to start-of-day to avoid duplicate same-day rows
        let day = Calendar.current.startOfDay(for: date)

        // 1) Derive cadence if we can (speed / stepLength * 60)
        let derivedCadence: Double? = {
            guard let v = walkingSpeed, let l = stepLength, l > 0 else { return nil }
            return (v / l) * 60.0
        }()

        // 2) Safe fallbacks from current target (so we don't write junk)
        let target = BaselineStore.shared.target
        let cadence = derivedCadence ?? (target.avgStepTime > 0 ? (60.0 / target.avgStepTime) : 0)
        let avgStep = cadence > 0 ? (60.0 / cadence) : target.avgStepTime
        let cvStep  = target.cvStepTime
        let sway    = target.mlSwayRMS
        let asymVal = asymPct ?? 0

        // 3) Update same-day entry or append new one
        if let i = sessions.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
            let existing = sessions[i]
            let newTags = Array(Set(existing.tags + ["passive"]))
            let updated = SessionSummary(
                id: existing.id,
                date: day,
                steps: steps,
                cadenceSPM: cadence,
                mlSwayRMS: sway,
                symmetryScore: existing.symmetryScore,   // preserve if you have a value
                tags: newTags,
                avgStepTime: avgStep,
                cvStepTime: cvStep,
                asymStepTimePct: asymVal
            )
            sessions[i] = updated
        } else {
            let new = SessionSummary(
                id: UUID(),
                date: day,
                steps: steps,
                cadenceSPM: cadence,
                mlSwayRMS: sway,
                symmetryScore: 0,
                tags: ["passive"],
                avgStepTime: avgStep,
                cvStepTime: cvStep,
                asymStepTimePct: asymVal
            )
            sessions.append(new)
        }

        objectWillChange.send()
    }
}

