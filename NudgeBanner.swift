import SwiftUI

struct NudgeBanner: View {
    let title: String
    let reasons: [String]
    let actionTitle: String
    var action: () -> Void
    var notNow: (() -> Void)? = nil    // optional secondary action

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text(title).font(.headline)
                Spacer()
                if let notNow {
                    Button("Not now") { notNow() }
                        .buttonStyle(.bordered)
                }
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
            if !reasons.isEmpty {
                ForEach(reasons, id: \.self) { r in
                    Label(r, systemImage: "arrow.up.right.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

