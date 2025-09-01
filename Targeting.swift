import Foundation
import SwiftUI

// MARK: - Target policy & computed target for BaselineStore
//
// This does NOT change your existing BaselineStore storage.
// It just adds a computed "target" (what “good” looks like) while the saved
// personal baseline remains the user's starting point for progress.

extension BaselineStore {

    // Where to aim: norms, personal (unchanged), or a ramp toward norms.
    enum TargetPolicy: String, CaseIterable, Codable {
        case norms       // always use age-typical norms
        case ramped      // gradually move from starting point toward norms
        case personal    // use the saved personal baseline as-is
    }

    // Persist policy + ramp fraction in UserDefaults (no stored props in extension)
    private var _policyKey: String { "GaitCoach.TargetPolicy.v1" }
    private var _rampKey: String   { "GaitCoach.TargetRamp.v1" }

    var targetPolicy: TargetPolicy {
        get {
            if let raw = UserDefaults.standard.string(forKey: _policyKey),
               let v = TargetPolicy(rawValue: raw) {
                return v
            }
            return .norms
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: _policyKey)
            objectWillChange.send()
        }
    }

    /// Ramp fraction 0…1 used when `targetPolicy == .ramped`
    /// 0 = personal baseline, 1 = norms.
    var rampFraction: Double {
        get { max(0, min(1, UserDefaults.standard.double(forKey: _rampKey))) }
        set {
            UserDefaults.standard.set(max(0, min(1, newValue)), forKey: _rampKey)
            objectWillChange.send()
        }
    }

    /// Advance the ramp by a small step (e.g., monthly).
    func advanceRamp(by delta: Double) {
        rampFraction = max(0, min(1, rampFraction + delta))
    }

    // MARK: Target = where we want the user to go
    //
    // - If no personal baseline yet, we still return a sensible target (norms).
    // - If ramped: linearly interpolate from personal → norms by rampFraction.
    var target: Baseline {
        let norms = CoachNorms.defaultTypical
        guard let start = baseline else {
            // No personal baseline yet; aim at norms
            return norms
        }
        switch targetPolicy {
        case .norms:    return norms
        case .personal: return start
        case .ramped:   return start.interpolating(toward: norms, fraction: rampFraction)
        }
    }
}

// MARK: - Simple norms (renamed to avoid clashes with any existing `Norms`)
private enum CoachNorms {
    /// Typical adult values used in the UI
    static let defaultTypical: Baseline = Baseline(
        date: Date(),           // required by your Baseline type
        avgStepTime: 0.26,      // seconds
        cvStepTime:  0.006,     // 0.6 %
        mlSwayRMS:   0.040,     // g
        asymStepTimePct: 0.0    // fill required field with neutral default
    )
}

// MARK: - Math helpers on Baseline
private extension Baseline {
    func interpolating(toward other: Baseline, fraction t: Double) -> Baseline {
        Baseline(
            date: Date(), // interpolation result is a synthetic target; "now" is fine
            avgStepTime: avgStepTime + (other.avgStepTime - avgStepTime) * t,
            cvStepTime:  cvStepTime  + (other.cvStepTime  - cvStepTime)  * t,
            mlSwayRMS:   mlSwayRMS   + (other.mlSwayRMS   - mlSwayRMS)   * t,
            asymStepTimePct: asymStepTimePct + (other.asymStepTimePct - asymStepTimePct) * t
        )
    }
}

