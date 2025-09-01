import Foundation

// MARK: - MuscleGroup helper (rename to avoid redeclaration)

extension MuscleGroup {
    /// Short human-readable label used in UI.
    var uiName: String {
        switch self {
        case .gluteMax:      return "Glute Max"
        case .gluteMed:      return "Glute Med"
        case .hipAbductors:  return "Hip Abductors"
        case .quads:         return "Quadriceps"
        case .core:          return "Core"
        @unknown default:    return rawValue.capitalized
        }
    }
}

// MARK: - Exercise model

struct ExerciseItem: Identifiable, Hashable, Codable, Equatable {
    let id: UUID
    let name: String
    let blurb: String
    let minutesDefault: Int
    let systemImage: String
    /// Prefer short, professional videos. If nil, UI can fall back to VideoLibrary.urlString(for:)
    let videoURL: String?
    let muscles: [MuscleGroup]

    init(
        id: UUID = UUID(),
        name: String,
        blurb: String,
        minutesDefault: Int = 3,
        systemImage: String,
        videoURL: String? = nil,
        muscles: [MuscleGroup] = []
    ) {
        self.id = id
        self.name = name
        self.blurb = blurb
        self.minutesDefault = minutesDefault
        self.systemImage = systemImage
        self.videoURL = videoURL
        self.muscles = muscles
    }
}

extension ExerciseItem {
    var durationLabel: String { "\(minutesDefault) min" }
    var muscleGroups: [MuscleGroup] { muscles }
    /// Prebuilt, simple string keeps SwiftUI type-checker happy.
    var muscleListLabel: String { muscles.map { $0.uiName }.joined(separator: " • ") }
}

// MARK: - Catalog (authoritative list + helpers)

enum ExerciseCatalog {

    static let generalStrength: [ExerciseItem] = [
        ExerciseItem(
            name: "Glute Bridge",
            blurb: "Drive through heels; ribs down; squeeze glutes.",
            minutesDefault: 3,
            systemImage: "figure.strengthtraining.traditional",
            videoURL: VideoLibrary.urlString(for: "Glute Bridge"),
            muscles: [.gluteMax, .core]
        ),
        ExerciseItem(
            name: "Sit-to-Stand (Tempo)",
            blurb: "Even up/down timing; nose over toes; slow, symmetrical control.",
            minutesDefault: 3,
            systemImage: "figure.seated.side.right",
            videoURL: VideoLibrary.urlString(for: "Sit-to-Stand (Tempo)"),
            muscles: [.quads, .gluteMax, .core]
        ),
        ExerciseItem(
            name: "Side-lying Hip Abduction",
            blurb: "Strict form; pelvis stacked; toes slightly down.",
            minutesDefault: 4,
            systemImage: "figure.strengthtraining.functional",
            videoURL: VideoLibrary.urlString(for: "Side-lying Hip Abduction"),
            muscles: [.gluteMed, .hipAbductors]
        )
    ]

    static let coachAccessories: [ExerciseItem] = [
        ExerciseItem(
            name: "Banded Lateral Walks",
            blurb: "Short steps; band at ankles or knees; keep pelvis level.",
            minutesDefault: 3,
            systemImage: "arrow.left.and.right",
            videoURL: VideoLibrary.urlString(for: "Banded Lateral Walks"),
            muscles: [.gluteMed, .hipAbductors]
        ),
        ExerciseItem(
            name: "Side-plank (modified → full)",
            blurb: "Hip abductor endurance with trunk control.",
            minutesDefault: 3,
            systemImage: "figure.core.training",
            videoURL: VideoLibrary.urlString(for: "Side-plank (modified → full)"),
            muscles: [.gluteMed, .core]
        ),
        ExerciseItem(
            name: "Wall-press Abduction Isometric",
            blurb: "Drive knee into wall, tall stance. Hold, breathe.",
            minutesDefault: 2,
            systemImage: "hand.raised",
            videoURL: VideoLibrary.urlString(for: "Wall-press Abduction Isometric"),
            muscles: [.gluteMed, .hipAbductors]
        )
    ]

    static var all: [ExerciseItem] {
        var seen = Set<String>()
        return (generalStrength + coachAccessories).filter { seen.insert($0.name).inserted }
    }

    static var exercises: [ExerciseItem] { all }

    static func byName(_ name: String) -> ExerciseItem? {
        all.first { $0.name == name }
    }

    static func defaultMinutes(for item: ExerciseItem) -> Int { item.minutesDefault }

    static func byMuscle(_ muscle: MuscleGroup) -> [ExerciseItem] {
        all.filter { $0.muscles.contains(muscle) }
    }

    /// Returns at most 3 exercises matched to the provided patterns.
    /// Returns at most 3 exercises matched to the provided pattern *tags*.
    /// Tags should be values from `GaitTag`.
    // inside ExerciseCatalog
    static func recommended(for patterns: [String]) -> [ExerciseItem] {
        var picks: [ExerciseItem] = []
        func add(_ name: String) { if let ex = byName(name) { picks.append(ex) } }

        if patterns.isEmpty {
            picks.append(contentsOf: generalStrength)
        } else {
            if patterns.contains(GaitTags.trendelenburgLike) || patterns.contains(GaitTags.ataxicWideBased) {
                ["Side-lying Hip Abduction", "Banded Lateral Walks", "Side-plank (modified → full)"].forEach(add)
            }
            if patterns.contains(GaitTags.antalgic) {
                ["Sit-to-Stand (Tempo)", "Glute Bridge", "Wall-press Abduction Isometric"].forEach(add)
            }
            if patterns.contains(GaitTags.shufflingShortSteps) {
                ["Sit-to-Stand (Tempo)", "Glute Bridge"].forEach(add)
            }
            if patterns.contains(GaitTags.irregularRhythm) {
                ["Sit-to-Stand (Tempo)"].forEach(add)
            }
        }

        var seen = Set<String>()
        let unique = picks.filter { seen.insert($0.name).inserted }
        return Array(unique.prefix(3))
    }
    static var quickAdd: [ExerciseItem] { Array(generalStrength.prefix(3)) }
}

