import Foundation

extension VideoLibrary {
    /// Returns the preferred video URL for an exercise.
    /// Uses the exercise's own `videoURL` if present; otherwise attempts a name match in the catalog.
    static func pickBestURL(for item: ExerciseItem) -> String? {
        if let v = item.videoURL, !v.isEmpty { return v }
        let match = ExerciseCatalog.exercises.first {
            $0.name.compare(item.name, options: .caseInsensitive) == .orderedSame
        }
        return match?.videoURL
    }
}

