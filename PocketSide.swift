import Foundation

/// Which pocket the phone is in (used by calibration & settings).
public enum PocketSide: String, CaseIterable, Codable {
    case left, right
}

