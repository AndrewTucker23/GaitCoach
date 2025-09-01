import Foundation
import Combine
import CoreMotion
import simd

// MARK: - Public surface other code uses

protocol MotionServiceType: AnyObject, ObservableObject {
    var stepCount: Int { get }          // cumulative steps (resets on start)
    var cadenceSPM: Double { get }      // steps per minute
    var mlSwayRMS: Double { get }       // ML sway proxy (RMS accel, body frame)
    var tiltDeg: Double { get }         // slow body tilt magnitude (degrees)
    var status: MotionStatus { get }
    var stepEvent: AnyPublisher<(Date, Double), Never> { get }  // (timestamp, ML-at-step)
    var bodySample: (fwd: Double, ml: Double, up: Double) { get }

    /// True only if we have a stored transform **and** its quality is good.
    var calibrationOK: Bool { get }

    func start()
    func stop()
}

enum MotionStatus: Equatable {
    case ok
    case noPermission
    case noMotion
    case error(String)

    var isBlocked: Bool { if case .ok = self { return false } else { return true } }
    var message: String {
        switch self {
        case .ok:           return "OK"
        case .noPermission: return "Motion permissions are off. Enable Motion & Fitness in Settings."
        case .noMotion:     return "Motion sensor not available on this device."
        case .error(let m): return m
        }
    }
}

// MARK: - Real device implementation (uses CoreMotion + BodyTransform)

final class MotionServiceDevice: MotionServiceType {

    // Public (ObservableObject) outputs
    @Published private(set) var stepCount: Int = 0
    @Published private(set) var cadenceSPM: Double = 0
    @Published private(set) var mlSwayRMS: Double = 0
    @Published private(set) var tiltDeg: Double = 0
    @Published private(set) var status: MotionStatus = .ok
    @Published private(set) var bodySample: (fwd: Double, ml: Double, up: Double) = (0,0,0)
    @Published private(set) var calibrationOK: Bool = false

    // CoreMotion
    private let mm = CMMotionManager()
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.qualityOfService = .userInitiated
        return q
    }()

    // Orientation calibration (optional)
    private let settings = UserSettingsStore.shared

    /// Bridge the stored DTO back into the runtime `BodyTransform`.
    private var transform: BodyTransform? {
        guard let dto = settings.bodyTransform else { return nil }
        let fwd = simd_double3(dto.m00, dto.m01, dto.m02)
        let ml  = simd_double3(dto.m10, dto.m11, dto.m12)
        let up  = simd_double3(dto.m20, dto.m21, dto.m22)
        return BodyTransform(fwd: fwd, ml: ml, up: up)
    }
    private var transformIsGood: Bool { settings.orientationQuality?.isGood ?? false }

    // Step events
    private let stepSubject = PassthroughSubject<(Date, Double), Never>()
    var stepEvent: AnyPublisher<(Date, Double), Never> { stepSubject.eraseToAnyPublisher() }

    // ML sway RMS buffer (~3 s @ 100 Hz)
    private var mlBuffer: [Double] = []
    private let mlCap = 300

    // Step detection / cadence
    private var fwdPrev: Double = 0
    private var lastStepTS: TimeInterval = 0
    private var lastCadenceTS: TimeInterval = 0

    // Tilt EMA (slow)
    private var tiltEMA: Double = 0
    private let tiltAlpha = 0.02    // ~2–3 s time constant at 100 Hz

    init() {}

    func start() {
        guard mm.isDeviceMotionAvailable else {
            status = .noMotion
            return
        }

        // Reset counters
        status = .ok
        stepCount = 0
        cadenceSPM = 0
        mlSwayRMS = 0
        tiltDeg = 0
        mlBuffer.removeAll()
        fwdPrev = 0
        lastStepTS = 0
        lastCadenceTS = 0
        tiltEMA = 0

        mm.deviceMotionUpdateInterval = 1.0 / 100.0

        mm.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: queue) { [weak self] dm, err in
            guard let self else { return }
            if let err {
                DispatchQueue.main.async { self.status = .error(err.localizedDescription) }
                return
            }
            guard let dm else { return }

            // Device-frame vectors
            let aDev = simd_double3(dm.userAcceleration.x, dm.userAcceleration.y, dm.userAcceleration.z)
            let gDev = simd_double3(dm.gravity.x,          dm.gravity.y,          dm.gravity.z) // points DOWN

            // Calibration available?
            let calOK = (self.transform != nil) && self.transformIsGood
            if self.calibrationOK != calOK {
                DispatchQueue.main.async { self.calibrationOK = calOK }
            }

            // Map to body frame if we have a good transform; else fall back to device axes
            let (fwd, ml, up): (Double, Double, Double) = {
                if let T = self.transform, calOK {
                    let ab = T.apply(aDev)
                    return (ab.forward, ab.ml, ab.up)
                } else {
                    return (aDev.x, aDev.y, aDev.z)
                }
            }()
            self.bodySample = (fwd, ml, up)

            // ---- ML sway RMS (body ML axis) ----
            self.mlBuffer.append(ml)
            if self.mlBuffer.count > self.mlCap {
                self.mlBuffer.removeFirst(self.mlBuffer.count - self.mlCap)
            }
            let meanSq = self.mlBuffer.reduce(0) { $0 + $1 * $1 } / Double(max(1, self.mlBuffer.count))
            let mlRMS = sqrt(meanSq)

            // ---- Slow "tilt" (gravity deviation from vertical in body frame) ----
            if let T = self.transform, calOK {
                // In body coords, we want gravity ≈ (0, 0, -1).
                let gb = T.apply(gDev)
                let horiz = sqrt(gb.forward * gb.forward + gb.ml * gb.ml)
                let newTilt = atan2(horiz, abs(gb.up)) * 180.0 / .pi
                self.tiltEMA = (self.tiltEMA == 0)
                    ? newTilt
                    : (self.tiltAlpha * newTilt + (1 - self.tiltAlpha) * self.tiltEMA)
            }

            // ---- Step detection on body "forward" axis ----
            let now = dm.timestamp
            let thresh = 0.9
            let minGap = 0.25

            var didStep = false
            if self.fwdPrev <= thresh, fwd > thresh, (now - self.lastStepTS) > minGap {
                self.lastStepTS = now
                didStep = true
            }
            self.fwdPrev = fwd

            if didStep {
                let stepDate = Date()
                DispatchQueue.main.async {
                    self.stepCount += 1
                    // Publish (timestamp, ML sign/value for labeling)
                    self.stepSubject.send((stepDate, ml))
                }

                // Cadence from last step interval
                if self.lastCadenceTS > 0 {
                    let dt = now - self.lastCadenceTS
                    if dt > 0.25 && dt < 2.0 {
                        let spm = min(200, max(0, 60.0 / dt))
                        DispatchQueue.main.async { self.cadenceSPM = spm }
                    }
                }
                self.lastCadenceTS = now
            }

            // Push smoothed values
            DispatchQueue.main.async {
                self.mlSwayRMS = mlRMS
                self.tiltDeg = self.tiltEMA
            }
        }
    }

    func stop() {
        mm.stopDeviceMotionUpdates()
    }
}

// MARK: - Simulator stub (keeps UI working in Simulator)

final class MotionServiceSim: MotionServiceType {
    @Published private(set) var stepCount: Int = 0
    @Published private(set) var cadenceSPM: Double = 96
    @Published private(set) var mlSwayRMS: Double = 0.06
    @Published private(set) var tiltDeg: Double = 0
    @Published private(set) var status: MotionStatus = .ok
    @Published private(set) var bodySample: (fwd: Double, ml: Double, up: Double) = (0.1, 0.0, 0.98)
    @Published private(set) var calibrationOK: Bool = true

    private let stepSubject = PassthroughSubject<(Date, Double), Never>()
    var stepEvent: AnyPublisher<(Date, Double), Never> { stepSubject.eraseToAnyPublisher() }

    private var timer: AnyCancellable?
    private var mlSign: Double = 1

    init() {}

    func start() {
        status = .ok
        stepCount = 0
        cadenceSPM = 96
        mlSwayRMS = 0.06
        tiltDeg = 2

        timer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.stepCount += 1
                self.mlSign *= -1
                let ml = 0.08 * self.mlSign + Double.random(in: -0.01...0.01)
                self.mlSwayRMS = 0.05 + Double.random(in: -0.01...0.01)
                self.cadenceSPM = 92 + Double.random(in: -5...5)
                self.bodySample = (0.2, ml, 0.95)
                self.stepSubject.send((Date(), ml))
            }
    }

    func stop() { timer?.cancel(); timer = nil }
}

// MARK: - Environment switch

#if targetEnvironment(simulator)
typealias MotionService = MotionServiceSim
#else
typealias MotionService = MotionServiceDevice
#endif

