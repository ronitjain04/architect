//
//  BottomNavigationBar.swift
//  ARchitect
//
//  Instagram-style bottom tab bar: a flat, top-bordered bar with Feed, Explore,
//  a prominent AR-create button, and Profile. Controlled and stateless — driven
//  by RootTabView, it just reports taps and reflects the selected tab.
//

import SwiftUI

struct BottomNavigationBar: View {
    @Binding var selectedTab: AppTab
    var onFeed: () -> Void
    var onExplore: () -> Void
    var onPlus: () -> Void
    var onProfile: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            tabButton(icon: "house", selectedIcon: "house.fill",
                      isSelected: selectedTab == .feed, action: onFeed)

            tabButton(icon: "magnifyingglass", selectedIcon: "magnifyingglass",
                      isSelected: selectedTab == .explore, action: onExplore)

            // Center AR create button — the emphasized action.
            Button(action: onPlus) {
                Image(systemName: "arkit")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.appOnPrimary)
                    .frame(width: 46, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color.appPrimary)
                    )
            }
            .frame(maxWidth: .infinity)

            profileButton
        }
        .padding(.top, 12)
        .padding(.bottom, 28)
        .padding(.horizontal, AppSpacing.sm)
        .background(
            Color.appBackground
                .overlay(Rectangle().fill(Color.appDivider).frame(height: 0.5), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var profileButton: some View {
        Button(action: onProfile) {
            Avatar(monogram: "M", size: 28)
                .overlay(
                    Circle().stroke(selectedTab == .profile ? Color.appText : Color.clear, lineWidth: 2)
                )
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func tabButton(icon: String, selectedIcon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: isSelected ? selectedIcon : icon)
                .font(.system(size: 24, weight: isSelected ? .semibold : .regular))
                .foregroundColor(.appText)
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ARViewControllerWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ARViewController {
        return ARViewController()
    }

    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {}
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.appBackground.ignoresSafeArea()
        BottomNavigationBar(
            selectedTab: .constant(.feed),
            onFeed: {},
            onExplore: {},
            onPlus: {},
            onProfile: {}
        )
    }
}
