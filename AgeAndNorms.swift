import Foundation

enum AgeGroup: String, CaseIterable, Identifiable, Codable {
    case y21_40 = "21–40"
    case y41_60 = "41–60"
    case y61_85 = "61–85"

    var id: String { rawValue }

    /// User-friendly label (good for pickers/settings)
    var label: String {
        switch self {
        case .y21_40: return "21–40 yrs"
        case .y41_60: return "41–60 yrs"
        case .y61_85: return "61–85 yrs"
        }
    }
}

struct CadenceNorms: Codable {
    let moderateSPM: Int   // ≈ 3 METs
    let met4SPM: Int       // ≈ 4 METs
    let met5SPM: Int       // ≈ 5 METs
    let vigorousSPM: Int?  // ≈ 6 METs (nil for 61–85)
}

enum Norms {
    static let cadenceByAge: [AgeGroup: CadenceNorms] = [
        // Adults 21–40 & 41–60
        .y21_40: .init(moderateSPM: 100, met4SPM: 110, met5SPM: 120, vigorousSPM: 130),
        .y41_60: .init(moderateSPM: 100, met4SPM: 110, met5SPM: 120, vigorousSPM: 130),

        // Adults 61–85 (vigorous threshold not typically used)
        .y61_85: .init(moderateSPM: 100, met4SPM: 110, met5SPM: 120, vigorousSPM: nil)
    ]

    /// Safe accessor so views never have to force-unwrap.
    static func cadence(for age: AgeGroup) -> CadenceNorms {
        cadenceByAge[age] ?? CadenceNorms(moderateSPM: 100, met4SPM: 110, met5SPM: 120, vigorousSPM: nil)
    }
}

