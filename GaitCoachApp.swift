import SwiftUI
import UserNotifications
import UIKit

@main
struct GaitCoachApp: App {
    @StateObject private var settings = UserSettingsStore.shared
    
    init() {
        // Global appearance so UIKit-backed views share our background.
        let bg = UIColor(red: 202/255, green: 252/255, blue: 224/255, alpha: 1) // #CAFCE0
        
        // Tables / collections transparent so SwiftUI backgrounds show through.
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
        UICollectionView.appearance().backgroundColor = .clear
        
        // Navigation bar
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = bg
        nav.titleTextAttributes      = [.foregroundColor: UIColor.black]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.black]
        UINavigationBar.appearance().standardAppearance   = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance    = nav
        
        // Tab bar
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = bg
        UITabBar.appearance().standardAppearance = tab
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tab
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // App-wide mint background
                GCTheme.background.ignoresSafeArea()
                
                Group {
                    if settings.onboardingComplete {
                        // Main 5-tab UI
                        AppTabView()
                    } else {
                        // On
                    }
                }
            }
        }
    }
}
