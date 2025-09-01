import Foundation
import SwiftUI

struct RedFlag: Identifiable {
    let id = UUID()
    let title: String
    let lines: [String]
    let color: Color
}

enum SafetyEngine {
    /// Very conservative screen using recent sessions vs baseline.
    static func redFlag(sessions: [SessionSummary], baseline: Baseline?) -> RedFlag? {
        guard !sessions.isEmpty else { return nil }
        let recent = Array(sessions.suffix(7))
        let highAsym = recent.filter { $0.asymStepTimePct >= 12 }.count >= 3
        let veryHighAsym = recent.contains { $0.asymStepTimePct >= 18 }
        let baseML = baseline?.mlSwayRMS ?? 0
        let highMLSway = baseML > 0 && recent.filter { $0.mlSwayRMS >= (baseML * 1.4) }.count >= 3

        if veryHighAsym {
            return RedFlag(
                title: "High asymmetry detected",
                lines: ["Several walks show ≥18% step-time asymmetry.",
                        "Consider pausing training and contacting your clinician."],
                color: .orange
            )
        }
        if highAsym || highMLSway {
            return RedFlag(
                title: "Ongoing gait irregularity",
                lines: ["Recent walks show elevated asymmetry and/or sway vs baseline.",
                        "Re-calibrate and share your weekly report with a clinician."],
                color: .yellow
            )
        }
        return nil
    }
}

struct SafetyBanner: View {
    let flag: RedFlag
    var onAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(flag.color)
                Text(flag.title).font(.headline)
                Spacer()
                if let onAction {
                    Button("Re-calibrate", action: onAction).buttonStyle(.borderedProminent)
                }
            }
            ForEach(flag.lines, id: \.self) { l in
                Label(l, systemImage: "xmark.circle").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

