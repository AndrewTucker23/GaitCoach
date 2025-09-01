import Foundation

/// Simple user-entered sex option used in onboarding/settings.
/// (Separate from HealthKit’s HKBiologicalSex.)
enum Sex: String, CaseIterable, Identifiable, Codable {
    case female = "Female"
    case male   = "Male"
    case other  = "Other / Non-binary"
    case preferNot = "Prefer not to say"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .female: return "Female"
        case .male:   return "Male"
        case .other:  return "Other"
        case .preferNot: return "Prefer not"
        }
    }
}

