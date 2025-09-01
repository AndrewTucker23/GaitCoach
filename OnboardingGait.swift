import SwiftUI

struct OnboardingGate: View {
    @AppStorage("didOnboard") private var didOnboard = false

    var body: some View {
        TabView {
            OnboardCard(title: "Calibrate",
                        text: "Walk ~60 steps to set your personal baseline.")
            OnboardCard(title: "Your score",
                        text: "We combine rhythm, stability and cadence.")
            OnboardCard(title: "Health data",
                        text: "We read steps & motion to coach you.")
        }
        .tabViewStyle(.page)
        .overlay(alignment: .bottom) {
            Button("Get started") { didOnboard = true }
                .buttonStyle(.borderedProminent)
                .padding()
        }
    }
}

private struct OnboardCard: View {
    let title: String, text: String
    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.largeTitle.bold())
            Text(text)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

