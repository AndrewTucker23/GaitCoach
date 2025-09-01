import SwiftUI

struct SafetyDisclaimerView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Safety & Scope")
                    .font(.title.bold())

                Text("This app offers gait monitoring and coaching based on wearable sensor data. It is not a medical device and does not provide a diagnosis.")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Red flags — seek care if you experience:")
                        .font(.headline)
                    Text("• New or worsening severe pain")
                    Text("• Sudden swelling, redness, or warmth")
                    Text("• Repeated falls, fainting, or new weakness/numbness")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Best practices")
                        .font(.headline)
                    Text("• Walk in safe areas with appropriate footwear.")
                    Text("• Stop if you feel unwell or dizzy.")
                    Text("• Share your weekly summary with a clinician if you’re in rehab.")
                }
            }
            .padding()
        }
        .navigationTitle("Safety & Scope")
    }
}

#Preview { SafetyDisclaimerView() }

