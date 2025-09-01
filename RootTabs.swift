import SwiftUI

struct RootTabs: View {
    var body: some View {
        TabView {
            SessionView()
                .tabItem { Label("Walk", systemImage: "figure.walk") }

            GaitProgressScreen()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }

            CalibrationView()
                .tabItem { Label("Calibrate", systemImage: "dot.scope") }
        }
    }
}

#Preview { RootTabs() }

