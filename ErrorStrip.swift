import SwiftUI

/// A compact, reusable banner for warnings/errors.
struct ErrorStrip: View {
    let message: String
    var systemImage: String = "exclamationmark.triangle.fill"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.red.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Warning")
        .accessibilityValue(message)
    }
}

