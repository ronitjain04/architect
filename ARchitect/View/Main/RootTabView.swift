//
//  RootTabView.swift
//  ARchitect
//
//  Single source of truth for top-level navigation.
//
//  Replaces the old pattern where GeneralView and ARMediaView each embedded
//  their own BottomNavigationBar full of NavigationLinks — which pushed a new
//  screen onto the stack every time you "switched tabs", stacking Home/Feed
//  endlessly. Here a real TabView owns tab state (so each tab keeps its own
//  navigation + scroll position), the native tab bar is hidden, and a single
//  floating BottomNavigationBar drives selection.
//

import SwiftUI

enum AppTab: Hashable {
    case home
    case feed
}

struct RootTabView: View {
    @State private var selectedTab: AppTab = .home

    // One navigation path per tab so each tab keeps its own stack and we can
    // pop-to-root when the user re-taps the tab they're already on.
    @State private var homePath = NavigationPath()
    @State private var feedPath = NavigationPath()

    @State private var isShowingAR = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NavigationStack(path: $homePath) {
                    GeneralView()
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.home)

                NavigationStack(path: $feedPath) {
                    ARMediaView()
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.feed)
            }

            BottomNavigationBar(
                selectedTab: $selectedTab,
                onHome: { select(.home) },
                onPlus: { isShowingAR = true },
                onFeed: { select(.feed) }
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
        if selectedTab == tab {
            switch tab {
            case .home: homePath = NavigationPath()
            case .feed: feedPath = NavigationPath()
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
