import SwiftUI

struct ProgressRing: View {
    let value: Double
    let total: Double
    let lineWidth: CGFloat = 10

    var body: some View {
        let pct = total > 0 ? value / total : 0
        ZStack {
            Circle().stroke(lineWidth: lineWidth).opacity(0.15)
            Circle()
                .trim(from: 0, to: pct)
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .foregroundStyle(GC.color.accent)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: pct)
        }
        .frame(width: 56, height: 56)
        .accessibilityLabel("Plan progress")
        .accessibilityValue("\(Int(pct * 100)) percent")
    }
}

