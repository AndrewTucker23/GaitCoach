import Foundation
import Combine

struct Baseline: Codable {
    let date: Date
    let avgStepTime: Double     // seconds
    let cvStepTime: Double      // 0.0–1.0  (e.g., 0.08 = 8%)
    let mlSwayRMS: Double       // g
    let asymStepTimePct: Double // NEW: % step-time asymmetry saved from calibration
}

// For migration if you had an old save without asymStepTimePct
private struct Baseline_v0: Codable {
    let date: Date
    let avgStepTime: Double
    let cvStepTime: Double
    let mlSwayRMS: Double
}

final class BaselineStore: ObservableObject {
    static let shared = BaselineStore()

    @Published private(set) var baseline: Baseline?

    private let key = "GaitCoach.Baseline.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key) {
            if let b = try? JSONDecoder().decode(Baseline.self, from: data) {
                baseline = b
            } else if let old = try? JSONDecoder().decode(Baseline_v0.self, from: data) {
                // Migrate: assume 0% asymmetry if we don’t know it
                baseline = Baseline(date: old.date,
                                    avgStepTime: old.avgStepTime,
                                    cvStepTime: old.cvStepTime,
                                    mlSwayRMS: old.mlSwayRMS,
                                    asymStepTimePct: 0.0)
                persist()
            }
        }
    }

    func save(_ b: Baseline) {
        baseline = b
        persist()
    }

    func reset() {
        baseline = nil
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func persist() {
        guard let b = baseline,
              let data = try? JSONEncoder().encode(b) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

// BaselineStore.swift
extension BaselineStore {
    /// Age-typical target used for “Typical for age”.
    /// (If you later wire this to an age/sex table, replace the constants below.)
    func targetForNorms() -> Baseline {
        return Baseline(
            date: Date.distantPast,     // sentinel; not user-specific
            avgStepTime: 0.26,          // seconds
            cvStepTime: 0.006,          // 0.6 %
            mlSwayRMS: 0.040,           // g
            asymStepTimePct: 0.0        // %
        )
    }
}
