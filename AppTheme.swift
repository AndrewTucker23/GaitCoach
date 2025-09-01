// AppTheme.swift
import SwiftUI

// MARK: - Design System

enum GCTheme {
    // Brand colors
    static let background = Color(red: 202/255, green: 252/255, blue: 224/255)  // #CAFCE0
    static let header     = Color(red:  39/255, green:  77/255, blue:  67/255)  // #274D43
    static let onHeader   = Color(red: 202/255, green: 252/255, blue: 224/255)  // #CAFCE0
    static let accent     = Color(red:  30/255, green: 111/255, blue:  92/255)  // spruce

    // Soft “card” surface on mint
    static let surface: Color = background.opacity(0.55)

    // UIKit twins (for appearance APIs)
    static let uiBackground = UIColor(red: 202/255, green: 252/255, blue: 224/255, alpha: 1)
    static let uiHeader     = UIColor(red:  39/255, green:  77/255, blue:  67/255, alpha: 1)
    static let uiOnHeader   = UIColor(red: 202/255, green: 252/255, blue: 224/255, alpha: 1)
}

// Mint behind List/Form contents
private struct GCBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(GCTheme.background.ignoresSafeArea())
    }
}
extension View {
    func gcBackground() -> some View { modifier(GCBackgroundModifier()) }
}

// MARK: - Global UIKit Appearances

enum GCThemeAppearance {
    /// Dark green tab bar with mint icons/titles (selected + unselected).
    static func applyTabBar() {
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = GCTheme.uiHeader

        let mint = GCTheme.uiOnHeader

        // Selected
        tab.stackedLayoutAppearance.selected.iconColor = mint
        tab.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: mint]
        tab.inlineLayoutAppearance.selected.iconColor = mint
        tab.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: mint]
        tab.compactInlineLayoutAppearance.selected.iconColor = mint
        tab.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: mint]

        // Unselected
        tab.stackedLayoutAppearance.normal.iconColor = mint
        tab.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: mint]
        tab.inlineLayoutAppearance.normal.iconColor = mint
        tab.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: mint]
        tab.compactInlineLayoutAppearance.normal.iconColor = mint
        tab.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: mint]

        UITabBar.appearance().standardAppearance = tab
        if #available(iOS 15.0, *) { UITabBar.appearance().scrollEdgeAppearance = tab }
        UITabBar.appearance().tintColor = mint
        UITabBar.appearance().unselectedItemTintColor = mint
    }

    /// Dark header with mint large title (for Today).
    static func applyTodayNavBar() {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = GCTheme.uiHeader
        nav.largeTitleTextAttributes = [.foregroundColor: GCTheme.uiOnHeader]
        nav.titleTextAttributes      = [.foregroundColor: GCTheme.uiOnHeader]
        UINavigationBar.appearance().standardAppearance   = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance    = nav
        UINavigationBar.appearance().tintColor            = GCTheme.uiOnHeader
    }

    /// Mint header with default text (for other tabs).
    static func applyDefaultNavBar() {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = GCTheme.uiBackground
        UINavigationBar.appearance().standardAppearance   = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance    = nav
        UINavigationBar.appearance().tintColor            = .label
    }
}

