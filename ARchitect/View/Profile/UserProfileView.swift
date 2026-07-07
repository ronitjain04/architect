//
//  UserProfileView.swift
//  ARchitect
//
//  Another user's profile — reached by tapping a username in the feed, a
//  post, or people search. Shows their stats and posts with a follow button.
//  Seeded demo authors have posts but no account; their profile still renders
//  and can be followed.
//

import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    let username: String

    @State private var publicUser: PublicUser?
    @State private var posts: [Post] = []
    @State private var followerCount = 0
    @State private var isLoading = true

    private var isSelf: Bool { session.profile?.username == username }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar
                HStack(spacing: AppSpacing.md) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.appText)
                    }
                    Text(username)
                        .font(AppFont.inter(15, .semibold))
                        .foregroundColor(.appText)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 48)

                Divider().background(Color.appDivider)

                ScrollView {
                    header

                    if isLoading {
                        ProgressView()
                            .tint(.appPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else if posts.isEmpty {
                        VStack(spacing: AppSpacing.sm) {
                            Image(systemName: "camera")
                                .font(.system(size: 36, weight: .light))
                                .foregroundColor(.appTextSecondary)
                            Text("No posts yet")
                                .font(AppFont.inter(16, .semibold))
                                .foregroundColor(.appText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                    } else {
                        PostGrid(posts: posts)
                            .padding(.top, 2)
                    }
                }
                .padding(.bottom, 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: username) { await load() }
    }

    private func load() async {
        isLoading = true
        async let user = SocialService.fetchUser(username: username)
        async let userPosts = SocialService.fetchPosts(byUsername: username)
        async let followers = SocialService.followerCount(of: username)
        publicUser = await user
        posts = await userPosts
        followerCount = await followers
        isLoading = false
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.lg) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.appAccent, lineWidth: 2.5)
                        .frame(width: 88, height: 88)
                    Avatar(monogram: username, size: 78)
                }

                HStack(spacing: 0) {
                    stat(value: "\(posts.count)", label: "posts")
                    stat(value: "\(followerCount)", label: "followers")
                    stat(value: "\(publicUser?.followingCount ?? 0)", label: "following")
                }
                .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(publicUser?.profile.displayName ?? username)
                    .font(AppFont.inter(14, .semibold))
                    .foregroundColor(.appText)
                if let bio = publicUser?.profile.bio, !bio.isEmpty {
                    Text(bio)
                        .font(AppFont.inter(13, .regular))
                        .foregroundColor(.appText)
                }
            }

            if !isSelf {
                FollowButton(username: username) { delta in
                    followerCount = max(0, followerCount + delta)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.md)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(AppFont.inter(17, .semibold))
                .foregroundColor(.appText)
            Text(label)
                .font(AppFont.inter(12, .regular))
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Follow / Following toggle. Brown-filled when not yet following,
/// quiet tan once following (Instagram's pattern).
struct FollowButton: View {
    @EnvironmentObject var session: SessionStore
    let username: String
    /// Called with +1 / -1 so the presenting view can adjust its follower
    /// count optimistically.
    var onToggle: (Int) -> Void = { _ in }

    var body: some View {
        let following = session.isFollowing(username)
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            session.toggleFollow(username)
            onToggle(following ? -1 : +1)
        } label: {
            Text(following ? "Following" : "Follow")
                .font(AppFont.inter(13, .semibold))
                .foregroundColor(following ? .appText : .appOnPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                        .fill(following ? Color.appSurfaceAlt : Color.appPrimary)
                )
        }
    }
}

#Preview {
    NavigationStack {
        UserProfileView(username: "bob")
            .environmentObject(SessionStore())
    }
}
