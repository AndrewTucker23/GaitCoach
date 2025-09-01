import Foundation

/// Curated video links for each exercise name used in the app.
/// Primary sources: Ask Doctor Jo, E3 Rehab, Bob & Brad.
/// If a name isn’t found, we bias a YouTube search to those channels.
enum VideoLibrary {

    private static let curated: [String: String] = [
        "Glute Bridge"                 : "https://www.youtube.com/watch?v=ytvP0oUDKYw",   // Ask Doctor Jo – Bridging
        "Sit-to-Stand (Tempo)"         : "https://www.youtube.com/watch?v=5yxfzyzEzBY",   // Ask Doctor Jo – STS
        "Side-lying Hip Abduction"     : "https://www.youtube.com/watch?v=YF66vUqOm0I",   // Ask Doctor Jo – SL hip abd
        "Banded Lateral Walks"         : "https://www.youtube.com/watch?v=U28EiwEVXwM",   // E3 Rehab – Lateral/Monster
        "Side-plank (modified → full)" : "https://www.youtube.com/watch?v=V4A0wIh5HNk",   // Ask Doctor Jo – Side Plank
        "Wall-press Abduction Isometric": "https://www.youtube.com/watch?v=y0J4Qg1f02M"   // E3 Rehab – Abductor iso
    ]

    private static let preferredChannels = [
        "Ask Doctor Jo", "E3 Rehab", "Bob & Brad"
    ]

    /// Public lookup used by the UI.
    static func urlString(for exerciseName: String) -> String? {
        if let url = curated[exerciseName] { return url }
        // Channel-biased search fallback
        let q = "\(preferredChannels.first!) \(exerciseName) exercise"
        let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        return "https://www.youtube.com/results?search_query=\(encoded)"
    }
}

// Back-compat shim if any old sites call via the catalog.
extension ExerciseCatalog {
    static func preferredVideoURL(for item: ExerciseItem) -> String? {
        VideoLibrary.urlString(for: item.name)
    }
    static func videoURL(for item: ExerciseItem) -> String? { preferredVideoURL(for: item) }
}

