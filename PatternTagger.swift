import Foundation

struct SessionMetrics {
    let cadenceSPM: Double
    let mlSwayRMS: Double
    let avgStepTime: Double?
    let cvStepTime: Double?
}

// Canonical machine tags (string constants).
enum GaitTags {
    static let trendelenburgLike   = "trendelenburgLike"
    static let antalgic            = "antalgic"
    static let ataxicWideBased     = "ataxicWideBased"
    static let shufflingShortSteps = "shufflingShortSteps"
    static let irregularRhythm     = "irregularRhythm"
}

func makePatternTags(metrics: SessionMetrics, baseline: Baseline?) -> [String] {
    var tags: [String] = []
    if metrics.cadenceSPM < 60 { return tags }

    let baseML = baseline?.mlSwayRMS
    let cv     = metrics.cvStepTime ?? 0
    let ml     = metrics.mlSwayRMS

    func isUp(_ value: Double, vs base: Double?, by percent: Double, floor: Double? = nil) -> Bool {
        if let f = floor, value < f { return false }
        guard let b = base, b > 0 else { return false }
        return value >= b * (1.0 + percent / 100.0)
    }

    let CV_HIGH_ABS: Double = 0.12
    let CV_CAUTION_ABS: Double = 0.07
    let ML_ABS_CAUTION: Double = 0.07
    let ML_ABS_HIGH: Double    = 0.10

    if isUp(ml, vs: baseML, by: 25, floor: ML_ABS_CAUTION) || ml >= ML_ABS_HIGH {
        tags.append(GaitTags.trendelenburgLike)
    }
    if cv >= CV_CAUTION_ABS && metrics.cadenceSPM <= 110 {
        tags.append(GaitTags.antalgic)
    }
    if ((ml >= ML_ABS_HIGH) || isUp(ml, vs: baseML, by: 40)) && cv >= CV_HIGH_ABS {
        tags.append(GaitTags.ataxicWideBased)
    }
    if metrics.cadenceSPM >= 110 && (cv >= CV_CAUTION_ABS || isUp(ml, vs: baseML, by: 25)) {
        tags.append(GaitTags.shufflingShortSteps)
    }
    if cv >= CV_HIGH_ABS && !tags.contains(GaitTags.irregularRhythm) {
        tags.append(GaitTags.irregularRhythm)
    }

    var seen = Set<String>()
    return tags.filter { seen.insert($0).inserted }
}

func gaitTitle(for tag: String) -> String {
    switch tag {
    case GaitTags.trendelenburgLike:   return "Possible Trendelenburg-like pattern"
    case GaitTags.antalgic:            return "Possible antalgic (pain-avoidance) pattern"
    case GaitTags.ataxicWideBased:     return "Possible wide-based/ataxic pattern"
    case GaitTags.shufflingShortSteps: return "Possible shuffling/short steps"
    case GaitTags.irregularRhythm:     return "Irregular step rhythm"
    default:                           return tag
    }
}

func bestPatternSuggestion(tags: [String]) -> String? {
    guard let first = tags.first else { return nil }
    return gaitTitle(for: first)
}

