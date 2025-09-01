import Foundation

/// Single source of truth for the app's muscle taxonomy.
public enum MuscleGroup: String, CaseIterable, Codable, Hashable, Identifiable {
    case gluteMed
    case hipAbductors
    case gluteMax
    case quads
    case hamstrings
    case calves
    case core
    case lateralCore
    case hipFlexors
    case dorsiflexors
    case balance
    case generalBalance

    public var id: String { rawValue }

    /// Human-readable names for UI.
    public var displayName: String {
        switch self {
        case .gluteMed:        return "Glute medius"
        case .hipAbductors:    return "Hip abductors"
        case .gluteMax:        return "Glute max"
        case .quads:           return "Quadriceps"
        case .hamstrings:      return "Hamstrings"
        case .calves:          return "Calves"
        case .core:            return "Core"
        case .lateralCore:     return "Lateral core / obliques"
        case .hipFlexors:      return "Hip flexors"
        case .dorsiflexors:    return "Dorsiflexors"
        case .balance:         return "Balance / Control"
        case .generalBalance:  return "General balance / control"
        }
    }

    /// Short chip label.
    public var shortLabel: String {
        switch self {
        case .gluteMed:        return "G. med"
        case .hipAbductors:    return "Abductors"
        case .gluteMax:        return "G. max"
        case .quads:           return "Quads"
        case .hamstrings:      return "Hams"
        case .calves:          return "Calves"
        case .core:            return "Core"
        case .lateralCore:     return "Lat. core"
        case .hipFlexors:      return "Hip flex."
        case .dorsiflexors:    return "Dorsiflex."
        case .balance, .generalBalance:
            return "Balance"
        }
    }

    /// SF Symbol to represent the group.
    public var systemImage: String {
        switch self {
        case .gluteMed, .hipAbductors: return "figure.strengthtraining.functional"
        case .gluteMax:                return "figure.strengthtraining.traditional"
        case .quads:                   return "figure.run"
        case .hamstrings:              return "figure.stand.line.dotted.figure.stand"
        case .calves, .dorsiflexors:   return "figure.walk.motion"
        case .core, .lateralCore:      return "shield.lefthalf.filled"
        case .hipFlexors:              return "arrow.up.right.circle"
        case .balance, .generalBalance:return "figure.cooldown"
        }
    }
}

/// Back-compat for any older code that referenced `Muscle`.
public typealias Muscle = MuscleGroup

