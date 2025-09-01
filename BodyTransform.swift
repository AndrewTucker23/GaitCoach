import Foundation
import simd

// Types are defined once in BodyAxes.swift.
// This file intentionally contains helpers only—no redeclarations.

public extension BodyTransform {
    /// Returns a defensively orthonormalized copy of the basis.
    func orthonormalized() -> BodyTransform {
        var u = simd_normalize(up)
        var f = simd_normalize(fwd)
        let m = simd_normalize(simd_cross(u, f))   // subject-left
        f = simd_normalize(simd_cross(m, u))
        return BodyTransform(fwd: f, ml: m, up: u)
    }
}

