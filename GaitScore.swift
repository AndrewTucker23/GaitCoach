// GaitScore.swift
import Foundation

public struct GaitScoreResult {
    public let total: Int
    public let components: [String: Int]   // "asym", "sway", "cadence"
    public let notes: [String]
}

public enum GaitScore {

    /// Compute a 0–100 gait score with light regularization.
    /// - Parameters:
    ///   - asymPct: Step-time asymmetry (%).
    ///   - mlRMS:   Body M/L RMS acceleration (g).
    ///   - cadenceSPM: Steps per minute.
    ///   - baselineAsym: Optional baseline asymmetry (%).
    ///   - baselineMLSway: Optional baseline M/L RMS (g).
    public static func compute(asymPct: Double,
                               mlRMS: Double,
                               cadenceSPM: Double,
                               baselineAsym: Double? = nil,
                               baselineMLSway: Double? = nil) -> GaitScoreResult {

        // -------- Asymmetry penalty (0…40) --------
        // 0 at ≤4%, full penalty by ~20%
        let asymStart = 4.0
        let asymSevere = 20.0
        let asymUnit = clamp((asymPct - asymStart) / (asymSevere - asymStart), 0, 1)
        let asymPenalty = 40.0 * asymUnit

        // -------- Sway penalty (0…35) --------
        // Reference threshold uses the better of normative and baseline (if present).
        // Typical good RMS ~0.05–0.08 g; we start penalizing near ref, saturate ~0.14 g.
        let swayRef: Double = {
            if let b = baselineMLSway, b > 0 {
                // allow ~25% headroom over baseline before penalties ramp
                return min(0.08, b * 1.25)
            }
            return 0.06
        }()
        let swaySevere = 0.14
        let swayUnit = clamp((mlRMS - swayRef) / max(1e-6, (swaySevere - swayRef)), 0, 1)
        let swayPenalty = 35.0 * swayUnit

        // -------- Cadence penalty (0…25) --------
        // No penalty inside 90–120 spm. Full penalty by 50 or 160 spm.
        let bandLo = 90.0, bandHi = 120.0
        let hardLo = 50.0, hardHi = 160.0
        let cadUnit: Double = {
            if cadenceSPM < bandLo {
                return clamp((bandLo - cadenceSPM) / (bandLo - hardLo), 0, 1)
            } else if cadenceSPM > bandHi {
                return clamp((cadenceSPM - bandHi) / (hardHi - bandHi), 0, 1)
            } else {
                return 0
            }
        }()
        let cadencePenalty = 25.0 * cadUnit

        // Combine
        let raw = 100.0 - (asymPenalty + swayPenalty + cadencePenalty)
        let total = Int(max(0, min(100, raw)).rounded())

        var notes: [String] = []
        if asymPenalty > 0 { notes.append(String(format: "Asymmetry %.1f%%", asymPct)) }
        if swayPenalty > 0 { notes.append(String(format: "M/L sway %.3f g", mlRMS)) }
        if cadencePenalty > 0 { notes.append(String(format: "Cadence %.0f spm", cadenceSPM)) }

        return GaitScoreResult(
            total: total,
            components: [
                "asym": Int(asymPenalty.rounded()),
                "sway": Int(swayPenalty.rounded()),
                "cadence": Int(cadencePenalty.rounded())
            ],
            notes: notes
        )
    }

    // MARK: utils
    private static func clamp(_ x: Double, _ a: Double, _ b: Double) -> Double {
        return min(max(x, a), b)
    }
}

