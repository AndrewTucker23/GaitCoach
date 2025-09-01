import SwiftUI

struct OnboardingView: View {

    // Local type to avoid clashes with any global `Sex`
    enum UserSex: String, CaseIterable, Identifiable {
        case female = "Female", male = "Male", other = "Other"
        var id: String { rawValue }
    }

    @StateObject private var settings = UserSettingsStore.shared

    // Prefilled from store on appear
    @State private var age: Int = 45
    @State private var sexUI: UserSex = .male
    @State private var heightCm: Int = 170
    @State private var weightKg: Int = 70
    @State private var allowPassive = true

    var body: some View {
        NavigationStack {
            Form {
                // ABOUT YOU
                Section {
                    LabeledRow("Age") {
                        InlineNumberBox(value: $age, range: 18...95, step: 1, unit: "")
                    }

                    Picker("Sex", selection: $sexUI) {
                        ForEach(UserSex.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }

                    LabeledRow("Height") {
                        InlineNumberBox(value: $heightCm, range: 120...220, step: 1, unit: "cm")
                    }

                    LabeledRow("Weight") {
                        InlineNumberBox(value: $weightKg, range: 35...200, step: 1, unit: "kg")
                    }
                } header: { Text("About you") }

                // COACHING
                Section {
                    Toggle("Enable passive coaching", isOn: $allowPassive)
                        .tint(.accentColor)
                    Text("You can change this anytime in Settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: { Text("Coaching") }

                // CONTINUE
                Section {
                    Button {
                        // Map age to your AgeGroup
                        let group: AgeGroup = (age <= 40) ? .y21_40
                                         : (age <= 60 ? .y41_60 : .y61_85)

                        // Save to central store
                        settings.ageGroup = group
                        settings.sex = mapToSex(sexUI)
                        settings.heightCm = heightCm
                        settings.weightKg = weightKg
                        settings.passiveCoachingEnabled = allowPassive
                        settings.onboardingComplete = true

                        // Apply passive coaching immediately
                        HealthKitManager.shared.setPassiveCoaching(allowPassive)

                        // Move to Calibration
                        TabRouter.shared.selected = .calibrate
                    } label: {
                        Label("Continue to Calibration", systemImage: "figure.walk.motion")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Welcome")
        }
        .onAppear { preloadFromStore() }
    }

    // MARK: - Prefill from store

    private func preloadFromStore() {
        settings.bootstrapDefaultsIfNeeded()

        allowPassive = settings.passiveCoachingEnabled
        sexUI       = mapToUserSex(settings.sex)
        heightCm    = settings.heightCmValue
        weightKg    = settings.weightKgValue
        age         = midpoint(for: settings.ageGroup)
    }

    // MARK: - Mapping helpers

    private func mapToUserSex(_ s: Sex) -> UserSex {
        switch s {
        case .female: return .female
        case .male:   return .male
        default:      return .other
        }
    }

    private func mapToSex(_ u: UserSex) -> Sex {
        switch u {
        case .female: return .female
        case .male:   return .male
        case .other:  return .preferNot
        }
    }

    private func midpoint(for group: AgeGroup) -> Int {
        switch group {
        case .y21_40: return 30
        case .y41_60: return 50
        case .y61_85: return 70
        }
    }
}

//
// MARK: - UI helpers
//

/// Simple row with a trailing custom control (keeps Form spacing tidy)
private struct LabeledRow<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            content
        }
    }
}

/// Boxed number with – / + and optional unit.
/// Use inside a row: `InlineNumberBox(value: $age, range: 18...95, step: 1, unit: "")`
private struct InlineNumberBox: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String

    var body: some View {
        HStack(spacing: 0) {
            Button {
                value = max(range.lowerBound, value - step)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 36, height: 32)
            }

            Divider().frame(height: 22)

            Text("\(value)\(unit.isEmpty ? "" : " \(unit)")")
                .font(.body.monospacedDigit())
                .frame(minWidth: 76)
                .padding(.horizontal, 8)

            Divider().frame(height: 22)

            Button {
                value = min(range.upperBound, value + step)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 36, height: 32)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.secondary.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

