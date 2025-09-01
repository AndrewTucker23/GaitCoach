import Foundation
import simd

// Canonical runtime types (single source of truth)

public struct BodyTransform: Codable, Equatable {
    public let fwd: simd_double3   // forward (anterior)
    public let ml:  simd_double3   // mediolateral (+left)
    public let up:  simd_double3   // up (superior)

    public init(fwd: simd_double3, ml: simd_double3, up: simd_double3) {
        // normalize + orthonormalize defensively
        let f = simd_normalize(fwd)
        let u = simd_normalize(up)
        let m = simd_normalize(simd_cross(u, f))      // right-handed basis
        let fFix = simd_normalize(simd_cross(m, u))
        self.fwd = fFix; self.ml = m; self.up = u
    }

    public static let identity = BodyTransform(
        fwd: simd_double3(1, 0, 0),
        ml:  simd_double3(0, 1, 0),
        up:  simd_double3(0, 0, 1)
    )

    @inlinable
    public func apply(_ v: simd_double3) -> (forward: Double, ml: Double, up: Double) {
        (simd_dot(fwd, v), simd_dot(ml, v), simd_dot(up, v))
    }
}

public struct OrientationQuality: Codable, Equatable {
    public let seconds: Double
    public let samples: Int
    public let upStability: Double        // 0…1
    public let forwardDominance: Double   // 0…1

    public init(seconds: Double, samples: Int, upStability: Double, forwardDominance: Double) {
        self.seconds = seconds
        self.samples = samples
        self.upStability = upStability
        self.forwardDominance = forwardDominance
    }

    public var isGood: Bool {
        upStability > 0.90 && forwardDominance > 0.60 && samples >= 300
    }
}

