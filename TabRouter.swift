import SwiftUI

/// App tabs
///
/// NOTE:
/// - `.more` is the new consolidated tab.
/// - `.coach` and `.settings` remain as *compatibility* cases so older code
///   or saved values won't break; we map them to `.more` below.
enum AppTab: String, CaseIterable, Hashable {
    case today
    case calibrate
    case walk
    case report
    case more
    case coach      // legacy
    case settings   // legacy
}

/// Simple router to switch tabs programmatically and persist selection.
final class TabRouter: ObservableObject {
    static let shared = TabRouter()

    @Published var selected: AppTab {
        didSet { UserDefaults.standard.set(selected.rawValue, forKey: Self.key) }
    }

    private static let key = "GaitCoach.SelectedTab.v3"

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.key)

        // Migrate legacy raw values to current tabs
        let migratedRaw: String = {
            guard let raw = saved else { return AppTab.today.rawValue }
            switch raw {
            case "plan":                return AppTab.today.rawValue       // old "Plan" tab -> Today
            case "coach", "settings":   return AppTab.more.rawValue        // both live under More now
            default:                    return raw
            }
        }()

        selected = AppTab(rawValue: migratedRaw) ?? .today
    }

    /// Convenience for programmatic navigation (maps legacy targets to `.more`).
    func go(_ tab: AppTab) {
        switch tab {
        case .coach, .settings:
            selected = .more
        default:
            selected = tab
        }
    }
}

