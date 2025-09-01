import SwiftUI

// 1) Hex init (safe, clamps bad input)
extension Color {
    init(hex: String, alpha: Double = 1.0) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8)  & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// 2) App palette
extension Color {
    static let appMintBG        = Color(hex: "#CAFCE0") // page background
    static let appTextPrimary   = Color.black           // main text (default)
    static let appTertiary      = Color(hex: "#2F5D50") // spruce accent
    static let appTertiaryLight = Color(hex: "#3E7A6B") // hover/selected
    static let appTertiaryDark  = Color(hex: "#274D43") // pressed/headers
    static let appTertiaryWarm  = Color(hex: "#B24B3D") // optional warm badge
}

// 3) One-line “mint page” modifier for Lists/Forms/ScrollViews
struct AppBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)               // hide default grouped bg
            .background(Color.appMintBG.ignoresSafeArea())  // mint behind everything
    }
}
extension View { func appBackground() -> some View { modifier(AppBackground()) } }

