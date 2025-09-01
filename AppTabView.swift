import SwiftUI

// Tabs that use the dark header style
private let darkHeaderTabs: Set<AppTab> = [.today, .calibrate, .walk, .report, .more]

struct AppTabView: View {
    @StateObject private var router = TabRouter.shared
    
    @AppStorage("didOnboard") private var didOnboard = false
    @State private var showOnboarding = false

    var body: some View {
        TabView(selection: $router.selected) {
            stack { TodayView() }
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(AppTab.today)

            stack { CalibrationView().navigationTitle("Calibration") }
                .tabItem { Label("Calibrate", systemImage: "target") }
                .tag(AppTab.calibrate)

            stack { SessionView().navigationTitle("Walk") }
                .tabItem { Label("Walk", systemImage: "figure.walk.motion") }
                .tag(AppTab.walk)

            stack { ReportView().navigationTitle("Report") }
                .tabItem { Label("Report", systemImage: "doc.text.magnifyingglass") }
                .tag(AppTab.report)

            stack { MoreView() }
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tag(AppTab.more)
            
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingGate()
                .interactiveDismissDisabled(!didOnboard)
                }
        }
        .tint(GCTheme.onHeader)
        .onAppear {
            GCThemeAppearance.applyTabBar()
            showOnboarding = !didOnboard
            if darkHeaderTabs.contains(router.selected) {
                GCThemeAppearance.applyTodayNavBar()
            } else {
                GCThemeAppearance.applyDefaultNavBar()
            }
        }
        
        .onChange(of: router.selected) { _, newValue in
            if darkHeaderTabs.contains(newValue) {
                GCThemeAppearance.applyTodayNavBar()
            } else {
                GCThemeAppearance.applyDefaultNavBar()
            }
        }
    }
}

// Helper for consistent NavigationStacks
private func stack<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    NavigationStack { content() }
}

