import Foundation
import Combine
import CoreMotion       // CMDeviceMotion
import simd             // simd_double3

// MARK: - Small DTOs (avoid name clashes)

/// 3×3 transform from phone-frame acceleration → body frame (forward, ML, up)
struct OrientationTransformDTO: Codable, Equatable {
    // Row-major 3×3
    var m00, m01, m02: Double
    var m10, m11, m12: Double
    var m20, m21, m22: Double

    /// Apply the transform to a phone-frame acceleration vector.
    func apply(_ v: simd_double3) -> (forward: Double, ml: Double, up: Double) {
        let forward = m00*v.x + m01*v.y + m02*v.z
        let ml      = m10*v.x + m11*v.y + m12*v.z
        let up      = m20*v.x + m21*v.y + m22*v.z
        return (forward, ml, up)
    }
}

/// Quality metadata for the orientation calibration.
struct OrientationQualityDTO: Codable, Equatable {
    var confidence: Double   // 0…1
    var hz: Double           // sampling rate used
    var durationSec: Double  // total calibration duration

    var isGood: Bool { confidence >= 0.7 && hz >= 80 && durationSec >= 8 }
}

// MARK: - Other settings bits

enum ProsthesisSide: String, CaseIterable, Identifiable, Codable {
    case none = "None"
    case left = "Left"
    case right = "Right"
    var id: String { rawValue }
}

// MARK: - Store

final class UserSettingsStore: ObservableObject {
    static let shared = UserSettingsStore()

    // Persisted keys
    private let ageKey         = "UserSettings.ageGroup"
    private let prosthesisKey  = "UserSettings.prosthesisSide"
    private let cueingKey      = "UserSettings.hapticCueing"
    private let passiveKey     = "UserSettings.passiveCoaching"

    // Profile
    private let sexKey         = "UserSettings.sex"
    private let heightKey      = "UserSettings.heightCm"
    private let weightKey      = "UserSettings.weightKg"

    // Onboarding gate
    private let onboardingKey  = "UserSettings.onboardingComplete"

    // Orientation calibration
    private let orientTxKey    = "UserSettings.orientTransform.v1"
    private let orientQKey     = "UserSettings.orientQuality.v1"

    // Settings
    @Published var ageGroup: AgeGroup                 { didSet { save() } }
    @Published var prosthesisSide: ProsthesisSide     { didSet { save() } }
    @Published var hapticCueingEnabled: Bool          { didSet { save() } }
    @Published var passiveCoachingEnabled: Bool       { didSet { save() } }

    // Profile
    @Published var sex: Sex                           { didSet { save() } }
    @Published var heightCm: Int?                     { didSet { save() } }
    @Published var weightKg: Int?                     { didSet { save() } }

    // Onboarding
    @Published var onboardingComplete: Bool           { didSet { save() } }

    // Orientation results (note: DTOs to avoid naming collisions)
    @Published var bodyTransform: OrientationTransformDTO?        { didSet { save() } }
    @Published var orientationQuality: OrientationQualityDTO?     { didSet { save() } }

    // MARK: Init / load

    private init() {
        let d = UserDefaults.standard

        if let raw = d.string(forKey: ageKey), let v = AgeGroup(rawValue: raw) {
            ageGroup = v
        } else {
            ageGroup = .y41_60
        }

        if let raw = d.string(forKey: prosthesisKey), let v = ProsthesisSide(rawValue: raw) {
            prosthesisSide = v
        } else {
            prosthesisSide = .none
        }

        hapticCueingEnabled    = d.object(forKey: cueingKey)  as? Bool ?? true
        passiveCoachingEnabled = d.object(forKey: passiveKey) as? Bool ?? true

        if let raw = d.string(forKey: sexKey), let v = Sex(rawValue: raw) {
            sex = v
        } else {
            sex = .preferNot
        }

        heightCm = d.object(forKey: heightKey) as? Int
        weightKg = d.object(forKey: weightKey) as? Int

        onboardingComplete = d.object(forKey: onboardingKey) as? Bool ?? false

        // Orientation calibration (decode if present)
        if let data = d.data(forKey: orientTxKey),
           let t = try? JSONDecoder().decode(OrientationTransformDTO.self, from: data) {
            bodyTransform = t
        } else {
            bodyTransform = nil
        }

        if let data = d.data(forKey: orientQKey),
           let q = try? JSONDecoder().decode(OrientationQualityDTO.self, from: data) {
            orientationQuality = q
        } else {
            orientationQuality = nil
        }

        bootstrapDefaultsIfNeeded()
    }

    // MARK: Save

    private func save() {
        let d = UserDefaults.standard
        d.set(ageGroup.rawValue,       forKey: ageKey)
        d.set(prosthesisSide.rawValue, forKey: prosthesisKey)
        d.set(hapticCueingEnabled,     forKey: cueingKey)
        d.set(passiveCoachingEnabled,  forKey: passiveKey)
        d.set(sex.rawValue,            forKey: sexKey)

        if let h = heightCm { d.set(h, forKey: heightKey) } else { d.removeObject(forKey: heightKey) }
        if let w = weightKg { d.set(w, forKey: weightKey) } else { d.removeObject(forKey: weightKey) }

        d.set(onboardingComplete, forKey: onboardingKey)

        // Orientation calibration
        if let t = bodyTransform, let data = try? JSONEncoder().encode(t) {
            d.set(data, forKey: orientTxKey)
        } else {
            d.removeObject(forKey: orientTxKey)
        }

        if let q = orientationQuality, let data = try? JSONEncoder().encode(q) {
            d.set(data, forKey: orientQKey)
        } else {
            d.removeObject(forKey: orientQKey)
        }
    }

    // MARK: - Convenience

    var heightCmValue: Int {
        get { heightCm ?? Defaults.heightCM }
        set { heightCm = newValue }
    }

    var weightKgValue: Int {
        get { weightKg ?? Defaults.weightKG }
        set { weightKg = newValue }
    }

    /// Map device-motion acceleration from phone frame to body frame (using our DTO).
    func bodyFrameSample(dm: CMDeviceMotion, using t: OrientationTransformDTO)
      -> (forward: Double, ml: Double, up: Double)
    {
        let aPhone = simd_double3(dm.userAcceleration.x,
                                  dm.userAcceleration.y,
                                  dm.userAcceleration.z)
        return t.apply(aPhone)
    }

    func bootstrapDefaultsIfNeeded() {
        if heightCm == nil || (heightCm ?? 0) <= 0 { heightCm = Defaults.heightCM }
        if weightKg == nil || (weightKg ?? 0) <= 0 { weightKg = Defaults.weightKG }
        if UserDefaults.standard.object(forKey: passiveKey) == nil {
            passiveCoachingEnabled = Defaults.coachingOn
        }
    }

    func resetForRecalibration() {
        onboardingComplete = false
        bootstrapDefaultsIfNeeded()
    }
}

// MARK: - Defaults

private enum Defaults {
    static let age        = 40
    static let heightCM   = 170
    static let weightKG   = 70
    static let coachingOn = true
}

