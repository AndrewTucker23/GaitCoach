import Foundation

enum FootSide { case left, right }

/// Labels steps by ML sign and maintains rolling metrics.
final class StepMetrics {
    // public outputs
    private(set) var lastSide: FootSide?
    private(set) var stepTimeCV: Double = 0         // 0..1
    private(set) var asymPct: Double = 0            // %
    
    // config
    private let maxPairs = 40                        // ~20 L/R pairs
    private let minDt: Double = 0.25
    private let maxDt: Double = 1.6
    private let mlDeadband: Double = 0.01            // ignore tiny ML

    // state
    private var lastTime: Date?
    private var leftDts: [Double] = []
    private var rightDts: [Double] = []
    private var allDts: [Double] = []

    /// Feed each detected step. `ml` is body-frame mediolateral accel at the step.
    func ingest(time: Date, ml: Double) {
        // Label foot from ML sign (hysteresis via deadband)
        let side: FootSide
        if ml > mlDeadband { side = .left }
        else if ml < -mlDeadband { side = .right }
        else { side = lastSide ?? .left } // if tiny, keep last label
        lastSide = side

        // Inter-step dt
        if let t0 = lastTime {
            let dt = time.timeIntervalSince(t0)
            if dt >= minDt && dt <= maxDt {
                allDts.append(dt)
                trim(&allDts, to: maxPairs * 2)
                if side == .left { leftDts.append(dt); trim(&leftDts, to: maxPairs) }
                else { rightDts.append(dt); trim(&rightDts, to: maxPairs) }
                recompute()
            }
        }
        lastTime = time
    }

    private func recompute() {
        // CV on last ~20 steps
        if allDts.count >= 5 {
            let m = mean(allDts)
            let v = variance(allDts, mean: m)
            stepTimeCV = m > 0 ? sqrt(v / Double(max(1, allDts.count - 1))) / m : 0
        }
        // Asymmetry on last ~10/foot
        if leftDts.count >= 2 && rightDts.count >= 2 {
            let L = mean(Array(leftDts.suffix(10)))
            let R = mean(Array(rightDts.suffix(10)))
            let denom = max(0.0001, (L + R) / 2.0)
            asymPct = abs(L - R) / denom * 100.0
        }
    }

    // utils
    private func trim(_ a: inout [Double], to cap: Int) { if a.count > cap { a.removeFirst(a.count - cap) } }
    private func mean(_ xs: [Double]) -> Double { xs.reduce(0, +) / Double(max(1, xs.count)) }
    private func variance(_ xs: [Double], mean m: Double) -> Double {
        xs.map { ($0 - m) * ($0 - m) }.reduce(0, +)
    }
}

