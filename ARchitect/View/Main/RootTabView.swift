//
//  RootTabView.swift
//  ARchitect
//
//  Single source of truth for top-level navigation, modelled on Instagram's
//  bottom tab bar: Feed · Explore · (AR create) · Profile.
//
//  A real TabView owns tab state (so each tab keeps its own navigation + scroll
//  position), the native tab bar is hidden, and a single floating
//  BottomNavigationBar drives selection. The center AR button presents the
//  capture experience as a full-screen cover.
//

import SwiftUI

enum AppTab: Hashable {
    case feed
    case explore
    case profile
}

struct RootTabView: View {
    @State private var selectedTab: AppTab = .feed

    // One navigation path per tab so each tab keeps its own stack and we can
    // pop-to-root when the user re-taps the tab they're already on.
    @State private var feedPath = NavigationPath()
    @State private var explorePath = NavigationPath()
    @State private var profilePath = NavigationPath()

    @State private var isShowingAR = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NavigationStack(path: $feedPath) {
                    ARMediaView()
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.feed)

                NavigationStack(path: $explorePath) {
                    FurnitureExploreView()
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.explore)

                NavigationStack(path: $profilePath) {
                    ProfileView()
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.profile)
            }

            BottomNavigationBar(
                selectedTab: $selectedTab,
                onFeed: { select(.feed) },
                onExplore: { select(.explore) },
                onPlus: { isShowingAR = true },
                onProfile: { select(.profile) }
            )
        }
        // Keep the bar anchored even when a keyboard appears.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $isShowingAR) {
            ARViewControllerWrapper()
                .ignoresSafeArea()
        }
    }

    /// Re-tapping the active tab pops it to root; tapping a different tab
    /// crossfades to it.
    private func select(_ tab: AppTab) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if selectedTab == tab {
            switch tab {
            case .feed: feedPath = NavigationPath()
            case .explore: explorePath = NavigationPath()
            case .profile: profilePath = NavigationPath()
            }
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                selectedTab = tab
            }
        }
    }
}

#Preview {
    RootTabView()
}
