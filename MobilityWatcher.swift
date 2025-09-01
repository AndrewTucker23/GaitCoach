import HealthKit
import UserNotifications

final class MobilityWatcher {
    static let shared = MobilityWatcher()
    private init() {}

    /// Public: turn passive/background coaching on or off.
    /// - When enabled: ensures HK auth and registers observer queries.
    /// - When disabled: tears down observer queries and background delivery.
    func configureBackgroundDelivery(_ enabled: Bool) {
        if enabled {
            HealthKitManager.shared.requestAuthorization { ok in
                guard ok else { return }
                HealthKitManager.shared.enableBackgroundDelivery()
            }
        } else {
            HealthKitManager.shared.disableBackgroundDelivery()
        }
    }

    // MARK: - One-shot daily evaluation used by observer queries

    /// Pulls recent mobility data from HealthKit, compares to baseline, and surfaces a nudge + local notification if warranted.
    func evaluateDailyMobility() {
        guard let asymType = HKObjectType.quantityType(forIdentifier: .walkingAsymmetryPercentage) else { return }

        HealthKitManager.shared.fetchRecent(for: asymType) { samples in
            // Values are in percent (0…100)
            let values = samples.map { $0.quantity.doubleValue(for: HKUnit.percent()) }
            guard values.count >= 3 else { return }

            let last7 = Array(values.suffix(7))
            let avg7 = last7.reduce(0, +) / Double(last7.count)

            // Use user's own baseline if available.
            let baselineAsym = BaselineStore.shared.baseline?.asymStepTimePct ?? 0.0

            // Heuristic: 7-day asymmetry >20% above baseline AND absolute > 2%.
            if baselineAsym > 0,
               (avg7 - baselineAsym) / max(baselineAsym, 0.0001) > 0.20,
               avg7 > 2.0 {

                BackgroundMonitor.shared.setSuggestion(
                    message: "Walking asymmetry has increased recently.",
                    reasons: ["7-day average is elevated vs your baseline"]
                )
                self.postLocalNotification(
                    title: "GaitCoach",
                    body: "We noticed increased asymmetry. Re-calibrate to keep your goals on track."
                )
            }
        }
    }

    // MARK: - Local notifications

    private func postLocalNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default   // <- no reference to settings.coachSound

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
            let id = "gc.nudge.\(UUID().uuidString)"
            let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(req, withCompletionHandler: nil)
        }
    }
}

