import SwiftUI
import UIKit

struct SettingsView: View {
    var body: some View {
        List {
            Section("Passive Monitoring") {
                Label("Status: On (uses Health data)", systemImage: "waveform.path.ecg")
                    .foregroundStyle(.secondary)

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Manage Health Permissions…", systemImage: "gearshape")
                }
            }

            Section("Coach") {
                Text("Configure coaching in Onboarding and the Coach tab. More options coming soon.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .gcBackground()                // mint container
        .listStyle(.insetGrouped)      // white “bubbles”
        .listRowBackground(Color.white)
        .listSectionSpacing(12)
        .navigationTitle("Settings")
        .onAppear { HealthBackground.shared.start() }
    }
}
