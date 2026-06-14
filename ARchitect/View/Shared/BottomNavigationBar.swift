//
//  BottomNavigationBar.swift
//  ARchitect
//
//  Created by Ronit Jain on 4/9/25.
//
//  Controlled, stateless bar driven by RootTabView. It no longer pushes views
//  onto the navigation stack — it just reports taps and reflects the selected
//  tab, which is what makes tab switching a smooth crossfade instead of an
//  ever-growing push stack.
//

import SwiftUI

struct BottomNavigationBar: View {
    @Binding var selectedTab: AppTab
    var onHome: () -> Void
    var onPlus: () -> Void
    var onFeed: () -> Void

    private let barColor = Color(red: 99/255, green: 83/255, blue: 70/255)
    private let iconColor = Color(red: 222/255, green: 204/255, blue: 177/255)

    var body: some View {
        HStack {
            Spacer()

            tabButton(
                icon: "house.fill",
                isSelected: selectedTab == .home,
                action: onHome
            )

            Spacer()

            // Center AR button — visually distinct, always actionable.
            Button(action: onPlus) {
                Image(systemName: "plus.app.fill")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(iconColor)
                    .scaleEffect(1.05)
            }

            Spacer()

            tabButton(
                icon: "newspaper.fill",
                isSelected: selectedTab == .feed,
                action: onFeed
            )

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(barColor.opacity(0.90))
        )
        .padding(.horizontal, 40)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private func tabButton(icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(iconColor)
                .padding(8)
                .background(
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.18) : Color.clear)
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
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
        Color(red: 255/255, green: 242/255, blue: 223/255).ignoresSafeArea()
        BottomNavigationBar(
            selectedTab: .constant(.home),
            onHome: {},
            onPlus: {},
            onFeed: {}
        )
    }
}
