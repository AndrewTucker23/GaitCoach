import SwiftUI

struct TargetSettingsView: View {
    @StateObject private var baseline = BaselineStore.shared
    @StateObject private var ramp     = AutoRampEngine.shared   // keep meters in sync

    var body: some View {
        Form {
            // MARK: Target policy
            Section("Target policy") {
                // Hidden label so we don't render a non-functional "Target" row
                Picker("", selection: $baseline.targetPolicy) {
                    // Typical for age + description
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Typical for age (Default)")
                        Text("Best for most people. Targets age-typical gait for your profile; progress updates automatically from your recent walks.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .tag(BaselineStore.TargetPolicy.norms)

                    // Personal baseline + description
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Personal baseline")
                        Text("Use during injury recovery or painful flares when your gait scores temporarily drop below your personal baseline.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .tag(BaselineStore.TargetPolicy.personal)
                }
                .pickerStyle(.inline)
                .labelsHidden()

                if baseline.targetPolicy == .norms {
                    meterCard(
                        title: "Progress toward typical",
                        fraction: ramp.towardTypical,
                        blurb: "Progress adjusts automatically based on your recent walking scores."
                    )
                } else {
                    meterCard(
                        title: "Consistency to your baseline",
                        fraction: ramp.baselineConsistency,
                        blurb: "How closely your recent walking matches your personal baseline."
                    )
                }
            }

            // MARK: Current target
            Section("Current target") {
                let t = baseline.target
                kv("Avg step time", String(format: "%.2f s", t.avgStepTime))
                kv("CV step time",  String(format: "%.1f%%", t.cvStepTime * 100))
                kv("M/L sway (RMS)", String(format: "%.3f g", t.mlSwayRMS))
            }

            // MARK: Starting point
            Section("Starting point") {
                if let b = baseline.baseline {
                    kv("Avg step time", String(format: "%.2f s", b.avgStepTime))
                    kv("CV step time",  String(format: "%.1f%%", b.cvStepTime * 100))
                    kv("M/L sway (RMS)", String(format: "%.3f g", b.mlSwayRMS))
                } else {
                    Text("No baseline saved yet. Calibrate from the **Calibrate** tab.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Targets & Goals")
        .onAppear { AutoRampEngine.shared.start() }   // safe to call again
    }

    // MARK: helpers

    private func kv(_ k: String, _ v: String) -> some View {
        HStack { Text(k); Spacer(); Text(v).foregroundStyle(.secondary).monospacedDigit() }
    }

    @ViewBuilder
    private func meterCard(title: String, fraction: Double, blurb: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(round(fraction * 100)))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            GradientMeter(fraction: fraction)

            Text(statusText(for: fraction))
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(statusColor(for: fraction).opacity(0.15), in: Capsule())
                .foregroundStyle(statusColor(for: fraction))

            Text(blurb)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func statusText(for f: Double) -> String {
        switch f {
        case ..<0.2:  return "Starting out"
        case ..<0.6:  return "Improving"
        default:      return "On track"
        }
    }

    private func statusColor(for f: Double) -> Color {
        switch f {
        case ..<0.2:  return .red
        case ..<0.6:  return .orange
        default:      return .green
        }
    }
}

private struct GradientMeter: View {
    let fraction: Double   // 0…1
    var body: some View {
        GeometryReader { geo in
            let w = max(0, min(1, fraction)) * geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.secondary.opacity(0.18))
                Capsule()
                    .fill(LinearGradient(
                        colors: [.red, .orange, .yellow, .green],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: w)
            }
        }
        .frame(height: 18)
        .clipShape(Capsule())
    }
}

