import Foundation

enum GaitPattern: String, CaseIterable, Codable {
    case trendelenburgLike
    case antalgic
    case ataxicWideBased
    case shufflingShortSteps
    case irregularRhythm

    var displayName: String {
        switch self {
        case .trendelenburgLike: return "Trendelenburg-like"
        case .antalgic:          return "Antalgic"
        case .ataxicWideBased:   return "Ataxic / Wide-based"
        case .shufflingShortSteps:return "Shuffling / Short steps"
        case .irregularRhythm:   return "Irregular rhythm"
        }
    }

    /// Primary muscles to target for each pattern (kept to your existing groups)
    var muscles: [MuscleGroup] {
        switch self {
        case .trendelenburgLike: return [.gluteMed, .hipAbductors, .core]
        case .antalgic:          return [.quads, .gluteMax, .core]
        case .ataxicWideBased:   return [.gluteMed, .hipAbductors, .core]
        case .shufflingShortSteps:return [.gluteMax, .core]
        case .irregularRhythm:   return [.core]
        }
    }
}

