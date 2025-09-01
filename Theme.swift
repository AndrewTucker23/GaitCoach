import SwiftUI

enum GC {
    static let corner: CGFloat = 16
    static let pad: CGFloat = 12

    struct Colors {
        let accent = Color.accentColor
        let cardBG = Color(.secondarySystemGroupedBackground)
        let subtle = Color.secondary
        let good   = Color.green
        let warn   = Color.orange
        let bad    = Color.red
    }
    static let color = Colors()
}

extension View {
    /// Standard card look used across the app.
    func gcCard() -> some View {
        self.padding(GC.pad)
            .background(GC.color.cardBG)
            .clipShape(RoundedRectangle(cornerRadius: GC.corner))
    }
}

