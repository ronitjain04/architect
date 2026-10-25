//
//  ActivityView.swift
//  ARchitect
//
//  The activity feed reached from the bell icon on the main feed: likes,
//  comments, and new followers on the signed-in user's content. Tapping a
//  row marks it read and navigates to the post or profile behind it.
//

import SwiftUI

struct ActivityView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = ActivityStore()

    @State private var selectedPost: Post?
    @State private var showPost = false
    @State private var selectedUsername: String?
    @State private var showProfile = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.md) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.appText)
                        .frame(width: 44, height: 44, alignment: .leading)
                }
                .accessibilityLabel("Back to feed")
                Text("Activity")
                    .font(AppFont.headline)
                    .foregroundStyle(Color.appText)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(height: 48)
            Divider().background(Color.appDivider)

            ZStack {
                Color.appBackground.ignoresSafeArea()
                if store.isLoading {
                    ProgressView().tint(.appPrimary)
                } else if store.notifications.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.notifications) { notification in
                                Button { handleTap(notification) } label: {
                                    row(for: notification)
                                }
                                .buttonStyle(.plain)
                                Divider().background(Color.appDivider)
                            }
                        }
                        .padding(.bottom, 90)
                    }
                }
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if let uid = session.user?.uid {
                store.start(uid: uid)
            }
        }
        .navigationDestination(isPresented: $showPost) {
            if let selectedPost {
                PostView(post: selectedPost)
            }
        }
        .navigationDestination(isPresented: $showProfile) {
            if let selectedUsername {
                UserProfileView(username: selectedUsername)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "bell")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.appTextSecondary)
            Text("No activity yet")
                .font(AppFont.inter(17, .semibold))
                .foregroundColor(.appText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func row(for notification: AppNotification) -> some View {
        HStack(spacing: AppSpacing.md) {
            Avatar(monogram: notification.actorUsername, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                (Text(notification.actorUsername).font(AppFont.inter(13, .semibold))
                 + Text(" \(actionText(for: notification.type))").font(AppFont.inter(13, .regular)))
                    .foregroundColor(.appText)
                Text(relativeTime(notification.createdAt))
                    .font(AppFont.inter(11, .regular))
                    .foregroundColor(.appTextSecondary)
            }

            Spacer()

            if !notification.read {
                Circle()
                    .fill(Color.appLike)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func actionText(for type: AppNotification.NotificationType) -> String {
        switch type {
        case .like: return "liked your post"
        case .comment: return "commented on your post"
        case .follow: return "started following you"
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(Int(diff / 60))m" }
        if diff < 86400 { return "\(Int(diff / 3600))h" }
        return "\(Int(diff / 86400))d"
    }

    private func handleTap(_ notification: AppNotification) {
        if let uid = session.user?.uid {
            store.markRead(notification, uid: uid)
        }
        switch notification.type {
        case .follow:
            selectedUsername = notification.actorUsername
            showProfile = true
        case .like, .comment:
            guard let postID = notification.postID else { return }
            Task {
                if let post = await SocialService.fetchPost(id: postID) {
                    selectedPost = post
                    showPost = true
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ActivityView()
            .environmentObject(SessionStore())
    }
}
