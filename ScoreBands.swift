import SwiftUI

enum ScoreBand {
    case good, caution, low

    static func from(score: Int) -> ScoreBand {
        switch score {
        case 85...100: return .good
        case 70..<85:  return .caution
        default:       return .low
        }
    }

    var label: String {
        switch self {
        case .good:    return "Good"
        case .caution: return "Caution"
        case .low:     return "Low"
        }
    }

    var color: Color {
        switch self {
        case .good:    return .green
        case .caution: return .yellow
        case .low:     return .red
        }
    }

    /// A small colored dot view you can drop anywhere
    @ViewBuilder
    func dot(size: CGFloat = 10) -> some View {
        Circle()
            .fill(color.opacity(0.85))
            .frame(width: size, height: size)
    }

    /// A capsule “chip” with text + color
    @ViewBuilder
    func chip(text: String? = nil) -> some View {
        let t = text ?? label
        Text(t)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .overlay(
                Capsule().stroke(color.opacity(0.5), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

