import Foundation
import CoreMotion
import simd

/// Collects ~N seconds of motion to estimate forward/ML axes in the horizontal plane.
/// Uses your canonical `BodyTransform` and `OrientationQuality` types from BodyAxes.swift.
final class OrientationCalibrator {
    private let mgr = CMMotionManager()
    private let side: PocketSide
    private let hz: Double
    private let seconds: Double

    // Running estimates in *device* coordinates
    private var gMean = simd_double3(0,0,0)
    private var up_dev = simd_double3(0,0,1)
    private var h1_dev = simd_double3(1,0,0)
    private var h2_dev = simd_double3(0,1,0)

    // 2×2 covariance in the device horizontal plane
    private var s_xx = 0.0, s_xy = 0.0, s_yy = 0.0
    private var n = 0

    init(side: PocketSide, hz: Double = 100, seconds: Double = 10) {
        self.side = side
        self.hz = hz
        self.seconds = seconds
    }

    func start(completion: @escaping (_ transform: BodyTransform?, _ quality: OrientationQuality) -> Void) {
        guard mgr.isDeviceMotionAvailable else {
            completion(nil, OrientationQuality(seconds: 0, samples: 0, upStability: 0, forwardDominance: 0))
            return
        }
        mgr.deviceMotionUpdateInterval = 1.0 / hz

        mgr.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: .main) { [weak self] dm, _ in
            guard let self, let dm else { return }

            // Up from gravity (gravity points down; we want +up).
            let g = simd_double3(dm.gravity.x, dm.gravity.y, dm.gravity.z)
            self.gMean += g
            let up = simd_normalize(-g)
            if !up.x.isNaN { self.up_dev = up }

            // Orthonormal horizontal basis in device frame.
            var h1 = simd_cross(self.up_dev, simd_double3(1,0,0))
            if simd_length(h1) < 1e-3 { h1 = simd_cross(self.up_dev, simd_double3(0,1,0)) }
            h1 = simd_normalize(h1)
            let h2 = simd_normalize(simd_cross(self.up_dev, h1))
            self.h1_dev = h1; self.h2_dev = h2

            // Project user acceleration into horizontal basis, update covariance.
            let a = simd_double3(dm.userAcceleration.x, dm.userAcceleration.y, dm.userAcceleration.z)
            let ax = simd_dot(a, h1)
            let ay = simd_dot(a, h2)
            self.s_xx += ax*ax
            self.s_xy += ax*ay
            self.s_yy += ay*ay
            self.n += 1

            // Stop after desired duration.
            if Double(self.n) >= self.hz * self.seconds {
                self.finish(completion: completion)
            }
        }
    }

    private func finish(completion: @escaping (_ transform: BodyTransform?, _ quality: OrientationQuality) -> Void) {
        mgr.stopDeviceMotionUpdates()

        guard n > 10 else {
            completion(nil, OrientationQuality(seconds: 0, samples: n, upStability: 0, forwardDominance: 0))
            return
        }

        // 2×2 covariance eigen-decomposition (closed form).
        let Sxx = s_xx / Double(n)
        let Sxy = s_xy / Double(n)
        let Syy = s_yy / Double(n)
        let tr  = Sxx + Syy
        let det = Sxx*Syy - Sxy*Sxy
        let root = max(0.0, (tr*tr)/4.0 - det)
        let lambda1 = tr/2.0 + sqrt(root)   // principal
        let lambda2 = tr/2.0 - sqrt(root)

        // Principal eigenvector (forward direction in the horizontal plane).
        let vx = Sxy
        let vy = lambda1 - Sxx
        var v = simd_double2(vx, vy)
        if simd_length(v) < 1e-9 { v = simd_double2(1,0) }
        v = simd_normalize(v)

        // Forward & ML in device space.
        let fwd = simd_normalize(v.x * h1_dev + v.y * h2_dev)
        var ml  = simd_normalize(simd_cross(up_dev, fwd))     // right-handed: ml = up × fwd
        if side == .right { ml = -ml }                        // keep +ML = subject-left

        // Quality metrics
        let meanG = gMean / Double(n)
        let upStability = min(1.0, max(0.0, simd_length(meanG)))                  // 1 = steady
        let denom = max(1e-9, lambda1 + max(lambda2, 0))
        let forwardDominance = max(0.0, min(1.0, lambda1 / denom))                // share along principal axis

        let t = BodyTransform(fwd: fwd, ml: ml, up: up_dev)
        let q = OrientationQuality(seconds: Double(n) / hz,
                                   samples: n,
                                   upStability: upStability,
                                   forwardDominance: forwardDominance)
        completion(t, q)
    }
}

