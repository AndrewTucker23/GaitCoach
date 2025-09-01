// HealthBackground.swift
import Foundation
import HealthKit
import Combine

final class HealthBackground: ObservableObject {
    static let shared = HealthBackground()
    private let store = HKHealthStore()
    private var cancellables = Set<AnyCancellable>()

    // Persisted anchors so we only fetch new samples
    private let anchorKey = "GaitCoach.HKAnchors.v1"
    private var anchors: [String: Data] =
        (UserDefaults.standard.dictionary(forKey: "GaitCoach.HKAnchors.v1") as? [String: Data]) ?? [:] {
        didSet { UserDefaults.standard.set(anchors, forKey: anchorKey) }
    }

    // Call once (e.g., app launch)
    func start() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        // Request read access
        let typesToRead: Set<HKObjectType> = {
            var s: Set<HKObjectType> = [
                HKObjectType.quantityType(forIdentifier: .stepCount)!,
                HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
            ]
            if #available(iOS 16.0, *) {
                // Mobility metrics (availability varies by device)
                let ids: [HKQuantityTypeIdentifier] = [
                    .walkingSpeed,
                    .walkingStepLength,               // <- fixed name
                    .walkingAsymmetryPercentage,
                    .walkingDoubleSupportPercentage
                ]
                for id in ids {
                    if let t = HKObjectType.quantityType(forIdentifier: id) { s.insert(t) }
                }
            }
            return s
        }()

        store.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] ok, _ in
            guard ok else { return }
            DispatchQueue.main.async { self?.setUpObservers(for: typesToRead) }
        }
    }

    private func setUpObservers(for types: Set<HKObjectType>) {
        for obj in types {
            guard let sampleType = obj as? HKSampleType else { continue }

            // 1) Observer: iOS wakes us for new data
            let observer = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completion, _ in
                self?.fetchNewSamples(for: sampleType) { completion() }
            }
            store.execute(observer)
            // Background delivery
            store.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { _, _ in }

            // 2) Also fetch once at startup
            fetchNewSamples(for: sampleType, completion: {})
        }
    }

    private func fetchNewSamples(for type: HKSampleType, completion: @escaping () -> Void) {
        // Restore anchor
        let key = type.identifier
        let anchor = (anchors[key]).flatMap {
            try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0)
        }

        let q = HKAnchoredObjectQuery(type: type, predicate: nil, anchor: anchor, limit: HKObjectQueryNoLimit) {
            [weak self] _, newSamples, _, newAnchor, _ in
            defer { completion() }

            guard let self = self else { return }
            // Save anchor
            if let a = newAnchor,
               let data = try? NSKeyedArchiver.archivedData(withRootObject: a, requiringSecureCoding: true) {
                self.anchors[key] = data
            }
            guard let samples = newSamples as? [HKQuantitySample], !samples.isEmpty else { return }
            self.ingest(samples: samples)
        }
        store.execute(q)
    }

    // Convert HK samples into your app’s summaries
    private func ingest(samples: [HKQuantitySample]) {
        // Example: aggregate by day and push to your SessionSummaryStore
        let grouped = Dictionary(grouping: samples) { sample in
            Calendar.current.startOfDay(for: sample.startDate)
        }
        for (day, daySamples) in grouped {
            var steps = 0.0
            var speedValues = [Double]()
            var stepLengthValues = [Double]()
            var asymValues = [Double]()
            var dsuValues = [Double]()

            for s in daySamples {
                switch s.quantityType.identifier {
                case HKQuantityTypeIdentifier.stepCount.rawValue:
                    steps += s.quantity.doubleValue(for: .count())

                case HKQuantityTypeIdentifier.walkingSpeed.rawValue:
                    speedValues.append(
                        s.quantity.doubleValue(for: HKUnit.meter().unitDivided(by: .second()))
                    )

                case HKQuantityTypeIdentifier.walkingStepLength.rawValue:   // <- fixed name
                    stepLengthValues.append(s.quantity.doubleValue(for: .meter()))

                case HKQuantityTypeIdentifier.walkingAsymmetryPercentage.rawValue:
                    asymValues.append(s.quantity.doubleValue(for: .percent()))

                case HKQuantityTypeIdentifier.walkingDoubleSupportPercentage.rawValue:
                    dsuValues.append(s.quantity.doubleValue(for: .percent()))

                default:
                    break
                }
            }

            // Push (or update) a lightweight “passive session” in your store.
            SessionSummaryStore.shared.upsertPassiveDay(
                date: day,
                steps: Int(steps),
                walkingSpeed: avg(speedValues),
                stepLength: avg(stepLengthValues),
                asymPct: avg(asymValues),
                doubleSupportPct: avg(dsuValues)
            )
        }
    }

    private func avg(_ xs: [Double]) -> Double? {
        xs.isEmpty ? nil : xs.reduce(0, +) / Double(xs.count)
    }
}

// NOTE: Removed the custom HKSampleType.identifier extension —
// HKObjectType/HKSampleType already provide `identifier`.

