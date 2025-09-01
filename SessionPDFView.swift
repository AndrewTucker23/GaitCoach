import SwiftUI

/// Optional annotation we show in the PDF (already used elsewhere in your app)
struct PatternSuggestion: Codable, Equatable {
    let title: String
    let hint: String
}

struct SessionPDFView: View {
    let session: SessionSummary
    let baseline: Baseline
    let ageGroup: AgeGroup
    let norms: CadenceNorms
    let patternSuggestion: PatternSuggestion?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Report")
                .font(.title.bold())

            section("Overview") {
                gridRow("Date", longDate(session.date))
                gridRow("Steps", "\(session.steps)")
                gridRow("Cadence", String(format: "%.0f spm", session.cadenceSPM))
                gridRow("M/L sway (RMS)", String(format: "%.3f g", session.mlSwayRMS))
                gridRow("Symmetry score", "\(session.symmetryScore)/100")
            }

            section("Timing") {
                gridRow("Avg step time", String(format: "%.2f s", session.avgStepTime))
                gridRow("Step time CV", String(format: "%.1f%%", session.cvStepTime * 100))
                gridRow("Step-time asymmetry", String(format: "%.1f%%", session.asymStepTimePct))
            }

            if !session.tags.isEmpty {
                section("Auto tags") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(session.tags, id: \.self) { t in
                            Label(t, systemImage: "exclamationmark.circle")
                        }
                    }
                }
            }

            section("Your baseline") {
                gridRow("Avg step time", String(format: "%.2f s", baseline.avgStepTime))
                gridRow("Step time CV", String(format: "%.1f%%", baseline.cvStepTime * 100))
                gridRow("M/L sway (RMS)", String(format: "%.3f g", baseline.mlSwayRMS))
                gridRow("Step-time asymmetry", String(format: "%.1f%%", baseline.asymStepTimePct))
            }

            section("Population targets (\(ageGroup.rawValue))") {
                gridRow("Moderate", "≥ \(norms.moderateSPM) spm")
                gridRow("≈4/5 METs", "≥ \(norms.met4SPM)/\(norms.met5SPM) spm")
                if let v = norms.vigorousSPM {
                    gridRow("Vigorous", "≥ \(v) spm")
                }
            }

            if let sug = patternSuggestion {
                section("Possible pattern (beta)") {
                    Text(sug.title).font(.headline)
                    Text(sug.hint).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    // MARK: - small helpers

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
        .padding(.top, 6)
    }

    private func gridRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
        .font(.subheadline.monospacedDigit())
    }

    private func longDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }
}

#Preview {
    // Build explicit demo models (NO `return` inside the ViewBuilder)
    let demoSession = SessionSummary(
        id: UUID(),
        date: Date(),
        steps: 432,
        cadenceSPM: 98.0,
        mlSwayRMS: 0.072,
        symmetryScore: 83,
        tags: ["Cadence below moderate target",
               "M/L sway ↑ vs your baseline (~24%)"],
        avgStepTime: 0.56,
        cvStepTime: 0.09,
        asymStepTimePct: 0.0
    )

    let demoBaseline = Baseline(
        date: Date(),
        avgStepTime: 0.56,
        cvStepTime: 0.09,
        mlSwayRMS: 0.060,
        asymStepTimePct: 0.0
    )

    let demoNorms = CadenceNorms(moderateSPM: 100, met4SPM: 110, met5SPM: 120, vigorousSPM: 130)

    let demoSuggestion = PatternSuggestion(
        title: "Possible antalgic pattern",
        hint: "Irregular timing without high cadence; try even foot contact time."
    )

    SessionPDFView(
        session: demoSession,
        baseline: demoBaseline,
        ageGroup: .y41_60,
        norms: demoNorms,
        patternSuggestion: demoSuggestion
    )
}

