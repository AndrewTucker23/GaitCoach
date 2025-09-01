import SwiftUI
import Combine

private let darkGreen = Color(red: 39/255, green: 77/255, blue: 67/255)

private enum ScreenOutcome: Equatable {
    case insufficient
    case normal
    case atypical(reasons: [String])
}

#if canImport(TipKit)
import TipKit
struct SaveBaselineTip: Tip {
    var title: Text { Text("Save this baseline") }
    var message: Text { Text("Use it as your starting point for progress.") }
}
#endif

struct CalibrationView: View {
    @StateObject private var settings = UserSettingsStore.shared
    @StateObject private var store    = BaselineStore.shared
    @StateObject private var motion   = MotionService()

    // Run state
    @State private var isCalibrating = false
    @State private var lastStepTime: Date?
    @State private var stepsSeen = 0

    // Buffers
    @State private var intervals: [Double] = []
    @State private var leftIntervals: [Double] = []
    @State private var rightIntervals: [Double] = []
    @State private var swaySamples: [Double] = []
    @State private var stepC: AnyCancellable?

    // Validation state
    @State private var isValidating = false
    @State private var validationC: AnyCancellable?
    @State private var validationAlert = false
    @State private var validationMessage = ""

    // Results + UI
    @State private var outcome: ScreenOutcome = .insufficient
    @State private var showSaved = false

    // Pocket orientation state
    @AppStorage("pocketSide") private var pocketSideRaw: String = PocketSide.left.rawValue
    private var pocketSide: PocketSide { PocketSide(rawValue: pocketSideRaw) ?? .left }
    @State private var orientQuality: OrientationQuality?
    @State private var orientTransform: BodyTransform?

    // Config
    private let neededSteps = 60
    private let maxBuffer   = 200

    private var norms: CadenceNorms { Norms.cadenceByAge[settings.ageGroup]! }

    #if canImport(TipKit)
    let saveTip = SaveBaselineTip()
    #endif

    var body: some View {
        NavigationStack {
            List {
                // Intro
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Walk naturally for ~\(neededSteps) steps. We’ll screen this session before saving a personal baseline.")
                            .foregroundStyle(.secondary)
                        HStack(spacing: 28) {
                            metric("Steps", "\(stepsSeen)")
                            metric("Cadence", "\(Int(motion.cadenceSPM.rounded())) spm")
                            metric("M/L sway", String(format: "%.3f g", motion.mlSwayRMS))
                        }
                    }
                } header: { SectionHeader("CALIBRATION") }

                // Live metrics
                Section {
                    if motion.calibrationOK {
                        metricsBlock
                        #if DEBUG
                        Text(String(format: "fwd: %.2f  ml: %.2f  up: %.2f", motion.bodySample.fwd, motion.bodySample.ml, motion.bodySample.up))
                            .font(.footnote).foregroundStyle(.secondary)
                        #endif
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Metrics paused—calibration quality low.")
                            Text("Tap **Calibrate Pocket Orientation**, then walk 20–30 steps.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                } header: { SectionHeader("LIVE METRICS (LAST ~20 STEPS)") }

                // Pocket orientation
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Pocket", selection: $pocketSideRaw) {
                            Text("Left").tag(PocketSide.left.rawValue)
                            Text("Right").tag(PocketSide.right.rawValue)
                        }
                        .pickerStyle(.segmented)
                        
                        HStack {
                            Button("Calibrate Pocket Orientation") {
                                let cal = OrientationCalibrator(side: pocketSide, hz: 100, seconds: 10)
                                cal.start { transform, quality in
                                    orientQuality = quality
                                    if let t = transform, quality.isGood {
                                        orientTransform = t
                                        persistOrientation(t, quality)
                                        // Transform DTO bridging (memberwise exists)
                                        settings.bodyTransform = makeDTO(from: t)
                                        // Quality DTO bridging (no memberwise; decode from JSON)
                                        if let qDTO = makeQualityDTO(from: quality) {
                                            settings.orientationQuality = qDTO
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(darkGreen)
                            .disabled(isCalibrating)
                            
                            if let q = orientQuality {
                                Text("Calibration quality: \(q.isGood ? "✅ Good" : "⚠️ Low")")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(q.isGood ? .green : .secondary)
                            }
                        }
                        
                        Text("Pocket side: \(pocketSide == .left ? "Left" : "Right")")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        
                        Button("Recalibrate") {
                            orientQuality = nil
                            orientTransform = nil
                            // Clear persisted copies so MotionService won’t keep using old transform
                            settings.bodyTransform = nil
                            settings.orientationQuality = nil
                            let d = UserDefaults.standard
                            d.removeObject(forKey: "UserSettings.orientTransform.v1")
                            d.removeObject(forKey: "UserSettings.orientQuality.v1")
                        }
                        .buttonStyle(.bordered)
                        .tint(darkGreen)
                        .disabled(isCalibrating)
                    }
                } header: { SectionHeader("POCKET ORIENTATION") }

                // Outcome + actions
                Section {
                    outcomeRows

                    HStack {
                        Button(isCalibrating ? "Stop" : "Start Calibration") { toggle() }
                            .buttonStyle(.borderedProminent)
                            .tint(darkGreen)
                            .foregroundStyle(.white)

                        Button("Reset") { reset() }
                            .buttonStyle(.borderedProminent)
                            .tint(darkGreen)
                            .foregroundStyle(.white)
                            .disabled(isCalibrating)
                    }

                    Button {
                        runValidation { ok, msg in
                            if ok {
                                saveBaseline()
                                showSaved = true
                            } else {
                                validationMessage = msg ?? "Validation failed. Please redo pocket calibration."
                                validationAlert = true
                            }
                        }
                    } label: {
                        Label(isValidating ? "Validating…" : "Save as Your Baseline", systemImage: "checkmark.seal")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(isCalibrating || isValidating || !(orientQuality?.isGood ?? false))
                    #if canImport(TipKit)
                    .popoverTip(saveTip)
                    #endif

                    if case .atypical = outcome {
                        Text("We’ll start you on **Clinical Targets** for now. Improve with exercises and re-calibrate later.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                // Existing baseline
                if let b = store.baseline {
                    Section {
                        Text(String(format: "Avg step time: %.2f s", b.avgStepTime))
                        Text(String(format: "Step time CV: %.1f%%", b.cvStepTime * 100))
                        Text(String(format: "Step-time asymmetry: %.1f%%", b.asymStepTimePct))
                        Text(String(format: "M/L sway RMS: %.3f g", b.mlSwayRMS))
                            .foregroundStyle(.secondary)

                        Button {
                            store.reset()
                        } label: {
                            Label {
                                Text("Reset Baseline").foregroundStyle(.red)
                            } icon: {
                                Image(systemName: "trash")
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(darkGreen)
                            }
                        }
                        .buttonStyle(.plain)
                    } header: { SectionHeader("CURRENT BASELINE") }
                }
            }
            .gcBackground()
            .listStyle(.insetGrouped)
            .listRowBackground(Color.white)
            .navigationTitle("Calibration")
        }
        .onDisappear { motion.stop() }
        .alert("Baseline saved", isPresented: $showSaved) { Button("OK", role: .cancel) { } } message: {
            Text("We’ll compare your future walks to this baseline and to age-matched targets.")
        }
        .alert("Validation failed", isPresented: $validationAlert) { Button("OK", role: .cancel) { } } message: {
            Text(validationMessage)
        }
    }

    // Persist BodyTransform/Quality to UserDefaults (extra safety)
    private func persistOrientation(_ t: BodyTransform, _ q: OrientationQuality) {
        let d = UserDefaults.standard
        if let tData = try? JSONEncoder().encode(t) { d.set(tData, forKey: "UserSettings.orientTransform.v1") }
        if let qData = try? JSONEncoder().encode(q) { d.set(qData, forKey: "UserSettings.orientQuality.v1") }
    }

    // ---- BRIDGES to legacy DTOs used by UserSettingsStore ----
    private func makeDTO(from t: BodyTransform) -> OrientationTransformDTO {
        OrientationTransformDTO(
            m00: t.fwd.x, m01: t.fwd.y, m02: t.fwd.z,
            m10: t.ml.x,  m11: t.ml.y,  m12: t.ml.z,
            m20: t.up.x,  m21: t.up.y,  m22: t.up.z
        )
    }

    /// Bridge `OrientationQuality` → `OrientationQualityDTO` via JSON encode/decode.
    /// Returns nil if decoding fails (e.g., schema drift).
    private func makeQualityDTO(from q: OrientationQuality) -> OrientationQualityDTO? {
        guard let data = try? JSONEncoder().encode(q) else { return nil }
        return try? JSONDecoder().decode(OrientationQualityDTO.self, from: data)
    }

    // MARK: - Short validation walk (unchanged API)
    private func runValidation(completion: @escaping (Bool, String?) -> Void) {
        guard orientQuality?.isGood == true else {
            completion(false, "Pocket orientation quality is low. Please recalibrate.")
            return
        }

        isValidating = true
        var ts: [Date] = []
        var mls: [Double] = []

        // Ensure motion is running for the 20–30 step validation
        motion.stop()
        motion.start()

        validationC = motion.stepEvent.sink { (date, ml) in
            ts.append(date)
            mls.append(ml)
            if ts.count >= 26 { finish() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { finish() }

        func finish() {
            guard isValidating else { return }
            isValidating = false
            validationC?.cancel(); validationC = nil
            motion.stop()

            guard ts.count >= 20 else {
                completion(false, "We didn’t see enough steps. Please try again with 20–30 steady steps.")
                return
            }

            var intervals: [Double] = []
            for i in 1..<ts.count { intervals.append(ts[i].timeIntervalSince(ts[i-1])) }
            let mean = intervals.reduce(0, +) / Double(intervals.count)
            let sd = sqrt(max(0, intervals.map { pow($0 - mean, 2) }.reduce(0, +) / Double(intervals.count)))
            let cv = sd / max(mean, 1e-6)
            let cadence = 60.0 / max(mean, 1e-6)

            var flips = 0, pairs = 0
            var last: Double?
            for v in mls {
                guard abs(v) > 0.01 else { continue }
                if let p = last { pairs += 1; if p * v < 0 { flips += 1 } }
                last = v
            }
            let flipRatio = pairs > 0 ? Double(flips)/Double(pairs) : 0

            var reasons: [String] = []
            if cadence < 50 || cadence > 160 { reasons.append("cadence \(Int(cadence)) spm out of range (50–160)") }
            if cv > 0.18 { reasons.append(String(format: "step timing unstable (CV %.1f%%)", cv*100)) }
            if flipRatio < 0.6 { reasons.append("M/L sign didn’t alternate reliably") }

            reasons.isEmpty ? completion(true, nil)
                             : completion(false, "Validation checks failed:\n• " + reasons.joined(separator: "\n• "))
        }
    }

    // MARK: - Subviews

    private var metricsBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            let avg = avgStepTime()
            let cv  = cvStepTime()
            let sta = stepTimeAsymPct()

            HStack { Text("Avg step time"); Spacer()
                Text(avg.map { String(format: "%.2f s", $0) } ?? "—").foregroundStyle(.secondary)
            }
            HStack { Text("Step time CV"); Spacer()
                Text(cv.map { String(format: "%.1f%%", $0 * 100) } ?? "—").foregroundStyle(.secondary)
            }
            HStack { Text("Step-time asymmetry"); Spacer()
                Text(String(format: "%.1f%%", sta))
                    .foregroundStyle(sta >= 12 ? .red : (sta >= 7 ? .orange : .secondary))
            }
        }
    }

    private var outcomeRows: some View {
        Group {
            switch outcome {
            case .insufficient:
                Label { Text("Collecting… need ~\(neededSteps) steps for screening") } icon: {
                    Image(systemName: "hourglass").symbolRenderingMode(.monochrome).foregroundStyle(darkGreen)
                }
            case .normal:
                Label("Screening looks normal. You can save this as your baseline.", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            case .atypical(let reasons):
                VStack(alignment: .leading, spacing: 6) {
                    Label("This walk looks atypical — baseline not saved.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    ForEach(reasons, id: \.self) { r in
                        Label(r, systemImage: "xmark.circle").foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack { Text(title).font(.caption); Text(value).font(.title3.monospacedDigit()) }
    }

    // MARK: - Control

    private func toggle() { isCalibrating ? stop() : start() }

    private func start() {
        guard !isCalibrating else { return }
        isCalibrating = true
        resetBuffers()
        motion.start()

        // Subscribe to body-frame step events
        stepC = motion.stepEvent
            .sink { value in
                let (date, ml) = value
                handleStep(at: date, ml: ml)
            }
    }

    private func stop() {
        guard isCalibrating else { return }
        isCalibrating = false
        motion.stop()
        stepC?.cancel(); stepC = nil
        outcome = screenCalibration()
    }

    private func reset() {
        guard !isCalibrating else { return }
        resetBuffers()
        outcome = .insufficient
    }

    private func resetBuffers() {
        lastStepTime = nil
        stepsSeen = 0
        intervals.removeAll()
        leftIntervals.removeAll()
        rightIntervals.removeAll()
        swaySamples.removeAll()
    }

    // MARK: - Step handling with ML sign (left/right)

    private func handleStep(at time: Date, ml: Double) {
        stepsSeen += 1

        if let last = lastStepTime {
            let dt = time.timeIntervalSince(last)
            if dt >= 0.25 && dt <= 1.6 {
                intervals.append(dt)
                if ml > 0 { leftIntervals.append(dt) } else { rightIntervals.append(dt) } // ML>0 → left
                swaySamples.append(motion.mlSwayRMS)
                trim()
            }
        }
        lastStepTime = time

        if stepsSeen >= neededSteps {
            outcome = screenCalibration()
        }
    }

    private func trim() {
        func trimArray(_ a: inout [Double], cap: Int) {
            if a.count > cap { a.removeFirst(a.count - cap) }
        }
        trimArray(&intervals, cap: maxBuffer)
        trimArray(&leftIntervals, cap: maxBuffer/2)
        trimArray(&rightIntervals, cap: maxBuffer/2)
        trimArray(&swaySamples, cap: maxBuffer)
    }

    // MARK: - Metrics

    private func avgStepTime() -> Double? {
        let last = intervals.suffix(20)
        guard !last.isEmpty else { return nil }
        return last.reduce(0, +) / Double(last.count)
    }

    private func cvStepTime() -> Double? {
        let last = intervals.suffix(20)
        guard last.count >= 5 else { return nil }
        let m = last.reduce(0, +) / Double(last.count)
        guard m > 0 else { return nil }
        let varSum = last.map { ($0 - m) * ($0 - m) }.reduce(0, +)
        let sd = sqrt(varSum / Double(last.count - 1))
        return sd / m
    }

    private func stepTimeAsymPct() -> Double {
        guard leftIntervals.count >= 2, rightIntervals.count >= 2 else { return 0 }
        let L = mean(leftIntervals.suffix(10))
        let R = mean(rightIntervals.suffix(10))
        let denom = max(0.0001, (L + R) / 2.0)
        return abs(L - R) / denom * 100.0
    }

    private func mean(_ xs: ArraySlice<Double>) -> Double {
        guard !xs.isEmpty else { return 0 }
        return xs.reduce(0, +) / Double(xs.count)
    }
    private func mean(_ xs: [Double]) -> Double {
        guard !xs.isEmpty else { return 0 }
        return xs.reduce(0, +) / Double(xs.count)
    }

    // MARK: - Screening logic

    private func screenCalibration() -> ScreenOutcome {
        guard stepsSeen >= neededSteps else { return .insufficient }

        var reasons: [String] = []

        let cad = motion.cadenceSPM
        if cad < 50 || cad > 160 { reasons.append("Cadence outside expected walking range") }

        if let cv = cvStepTime(), cv > 0.12 {
            reasons.append(String(format: "Step time CV high (%.1f%%)", cv * 100))
        }

        let sta = stepTimeAsymPct()
        if sta >= 12 { reasons.append("Step-time asymmetry high (≥12%)") }

        let ml = mean(swaySamples.suffix(40))
        if ml > 0.10 { reasons.append(String(format: "M/L sway elevated (%.3f g)", ml)) }

        _ = norms
        return reasons.isEmpty ? .normal : .atypical(reasons: reasons)
    }

    private func saveBaseline() {
        guard orientQuality?.isGood == true else { return }
        guard case .normal = outcome else { return }
        guard let avg = avgStepTime(), let cv = cvStepTime() else { return }
        let ml  = mean(swaySamples.suffix(40))
        let sta = stepTimeAsymPct()

        store.save(.init(
            date: Date(),
            avgStepTime: avg,
            cvStepTime: cv,
            mlSwayRMS: ml,
            asymStepTimePct: sta
        ))
    }
}

// MARK: - Small header helper

private struct SectionHeader: View {
    private let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
    }
}

#Preview { CalibrationView() }

