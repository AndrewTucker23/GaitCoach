import Foundation

/// Canonical string tags used by planner / catalog.
enum GaitTag {
    static let trendelenburgLike   = "trendelenburgLike"
    static let antalgic            = "antalgic"
    static let ataxicWideBased     = "ataxicWideBased"
    static let shufflingShortSteps = "shufflingShortSteps"
    static let irregularRhythm     = "irregularRhythm"
}

/// Lightweight rule-based detector that emits string tags.
/// (Keeps us independent of any particular enum definition.)
struct GaitPatternDetector {
    func detect(asymPct: Double,
                mlRMS: Double,
                cadenceSPM: Double,
                cvStepTime: Double) -> [String] {

        var out: [String] = []

        if mlRMS >= 0.10 && cvStepTime <= 0.18 {
            out.append(GaitTag.trendelenburgLike)
        }
        if asymPct >= 12 {
            out.append(GaitTag.antalgic)
        }
        if mlRMS >= 0.14 || (mlRMS >= 0.10 && cvStepTime >= 0.16) {
            out.append(GaitTag.ataxicWideBased)
        }
        if cvStepTime >= 0.18 {
            out.append(GaitTag.irregularRhythm)
        }
        if cadenceSPM >= 115 && asymPct < 12 && mlRMS < 0.12 {
            out.append(GaitTag.shufflingShortSteps)
        }

        // De-dupe, keep order
        var seen = Set<String>()
        return out.filter { seen.insert($0).inserted }
    }
}

