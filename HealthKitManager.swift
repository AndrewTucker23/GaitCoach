import HealthKit

final class HealthKitManager {
    static let shared = HealthKitManager()
    private init() {}

    private let store = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []

    // Mobility metrics the app cares about
    let typesToRead: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .walkingAsymmetryPercentage)!,
        HKObjectType.quantityType(forIdentifier: .walkingSpeed)!,
        HKObjectType.quantityType(forIdentifier: .walkingStepLength)!,
        HKObjectType.quantityType(forIdentifier: .walkingDoubleSupportPercentage)!
    ]

    // MARK: - Authorization

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }
        store.requestAuthorization(toShare: [], read: typesToRead) { ok, _ in
            DispatchQueue.main.async { completion(ok) }
        }
    }

    // MARK: - Background delivery

    func enableBackgroundDelivery() {
        // Avoid duplicates
        observerQueries.forEach { store.stop($0) }
        observerQueries.removeAll()

        for case let type as HKQuantityType in typesToRead {
            store.enableBackgroundDelivery(for: type, frequency: .daily) { _, _ in }

            let q = HKObserverQuery(sampleType: type, predicate: nil) { _, completionHandler, _ in
                // New mobility data → run passive check
                MobilityWatcher.shared.evaluateDailyMobility()
                completionHandler()
            }
            observerQueries.append(q)
            store.execute(q)
        }
    }

    func disableBackgroundDelivery() {
        observerQueries.forEach { store.stop($0) }
        observerQueries.removeAll()
        store.disableAllBackgroundDelivery { _, _ in }
    }

    /// Primary API used by Settings / app.
    func setPassiveCoaching(_ enabled: Bool) {
        enabled ? enableBackgroundDelivery() : disableBackgroundDelivery()
    }

    // MARK: - Queries

    /// Fetch recent samples for a quantity type (default last 14 days), sorted oldest → newest
    func fetchRecent(for type: HKQuantityType,
                     days: Int = 14,
                     completion: @escaping ([HKQuantitySample]) -> Void) {
        let now = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: now) else {
            completion([])
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

        let q = HKSampleQuery(sampleType: type,
                              predicate: predicate,
                              limit: HKObjectQueryNoLimit,
                              sortDescriptors: [sort]) { _, samples, _ in
            completion(samples as? [HKQuantitySample] ?? [])
        }
        store.execute(q)
    }
}

