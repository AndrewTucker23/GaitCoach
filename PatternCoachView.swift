import SwiftUI

struct PatternCoachView: View {
    @StateObject private var sessions = SessionSummaryStore.shared
    @StateObject private var baseline = BaselineStore.shared

    private var last: SessionSummary? { sessions.sessions.last }

    var body: some View {
        List {
            if let primary = primaryTagFromLast() {
                hero(primary)
                recommendationsList(for: primary)
            } else {
                Section {
                    Text("Do a walk session so we can analyze your gait pattern.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Your Gait Pattern")
    }

    // MARK: - Hero

    @ViewBuilder
    private func hero(_ tag: String) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(gaitTitle(for: tag)).font(.title3.bold())
                Text(gaitHint(for: tag)).foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        } header: {
            Text("Your pattern (from last session)")
        }
    }

    // MARK: - Compute from last session

    private func primaryTagFromLast() -> String? {
        guard let s = last else { return nil }
        let metrics = SessionMetrics(
            cadenceSPM: s.cadenceSPM,
            mlSwayRMS:  s.mlSwayRMS,
            avgStepTime: s.avgStepTime,
            cvStepTime:  s.cvStepTime
        )
        // Compare to TARGET, not starting point
        let tags = makePatternTags(metrics: metrics, baseline: baseline.target)
        return tags.first
    }

    // MARK: - Recommendations

    @ViewBuilder
    private func recommendationsList(for tag: String) -> some View {
        let items = exercises(for: tag)

        Text("RECOMMENDED EXERCISES")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .listRowBackground(Color.clear)

        if items.isEmpty {
            Text("No matches in your library yet.")
                .foregroundStyle(.secondary)
        } else {
            ForEach(items) { ex in
                HStack(spacing: 12) {
                    Image(systemName: ex.systemImage)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ex.name).font(.headline)
                        Text(ex.blurb)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(ex.minutesDefault) min")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { TabRouter.shared.selected = .today }
            }
        }
    }

    private func muscles(for tag: String) -> Set<MuscleGroup> {
        switch tag {
        case GaitTags.trendelenburgLike:   return [.gluteMed, .hipAbductors, .core]
        case GaitTags.antalgic:            return [.gluteMed, .core]
        case GaitTags.ataxicWideBased:     return [.core, .hipAbductors]
        case GaitTags.shufflingShortSteps: return [.quads, .gluteMax]
        case GaitTags.irregularRhythm:     return [.core]
        default:                            return []
        }
    }

    private func exercises(for tag: String) -> [ExerciseItem] {
        let target = muscles(for: tag)
        return ExerciseCatalog.exercises
            .filter { !Set($0.muscles).isDisjoint(with: target) }
            .sorted { $0.name < $1.name }
    }

    // MARK: - Local hint text

    private func gaitHint(for tag: String) -> String {
        switch tag {
        case GaitTags.trendelenburgLike:
            return "Try: stand tall over stance hip; focus on level pelvis."
        case GaitTags.antalgic:
            return "Try: even foot contact time; slow to a comfortable pace."
        case GaitTags.ataxicWideBased:
            return "Try: slightly narrow your path and look ahead; slower, steady steps."
        case GaitTags.shufflingShortSteps:
            return "Try: lift feet and lengthen steps slightly."
        case GaitTags.irregularRhythm:
            return "Try: walk to a steady beat; count 1–2–1–2."
        default:
            return "Focus on steady, comfortable steps."
        }
    }
}

