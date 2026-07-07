//
//  ARMediaView.swift
//  ARchitect
//
//  The social feed — redesigned as an Instagram-style timeline: a wordmark
//  header, a stories rail, and full-bleed post cards with the familiar
//  like / comment / share / save action bar.
//

import SwiftUI

struct ARMediaView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var feed = FeedStore()

    private var posts: [Post] { feed.posts }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                feedHeader

                Divider().background(Color.appDivider)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if feed.isLoading {
                            ProgressView()
                                .tint(.appPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 80)
                        } else if posts.isEmpty {
                            emptyFeed
                        } else {
                            ForEach(posts) { post in
                                FeedPostCard(post: post)
                            }
                        }
                    }
                    .padding(.bottom, 90) // clear the floating tab bar
                }
                .refreshable {
                    // The snapshot listener keeps the feed live; this is just
                    // the familiar gesture.
                    try? await Task.sleep(nanoseconds: 400_000_000)
                }
            }
        }
        // This view supplies its own header, so hide the native nav bar to
        // avoid a duplicate empty bar above it.
        .toolbar(.hidden, for: .navigationBar)
        // Security rules require a signed-in user, and a listener attached
        // pre-auth stays denied — so (re)attach whenever auth flips on.
        .task(id: session.isAuthenticated) {
            if session.isAuthenticated {
                feed.restart()
            } else {
                feed.stopListening()
            }
        }
    }

    private var emptyFeed: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "camera")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.appTextSecondary)
            Text("No posts yet")
                .font(AppFont.inter(17, .semibold))
                .foregroundColor(.appText)
            Text("Capture a space in AR to share the first one.")
                .font(AppFont.inter(13, .regular))
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var feedHeader: some View {
        HStack {
            Text("ARchitect")
                .font(AppFont.fraunces(26, .semibold))
                .foregroundColor(.appText)

            Spacer()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 10)
    }

}

#Preview {
    ARMediaView()
        .environmentObject(SessionStore())
}

// MARK: - Post image

/// Renders the post photo from whichever source the post carries: an
/// embedded JPEG (user-created posts), a bundled asset (seeded posts), or a
/// Storage download URL (future migration path).
struct PostImage: View {
    let post: Post

    var body: some View {
        if let data = post.imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let urlString = post.imageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.appTextSecondary)
                default:
                    ProgressView().tint(.appPrimary)
                }
            }
        } else {
            Image(post.imageName)
                .resizable()
                .scaledToFill()
        }
    }
}

// MARK: - Feed post card

struct FeedPostCard: View {
    @EnvironmentObject var session: SessionStore
    @ObservedObject var post: Post
    @State private var showComments = false
    @State private var showMenuSheet = false
    @State private var showHeartBurst = false
    @State private var goToDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row — tapping the author opens their profile.
            HStack(spacing: 10) {
                NavigationLink(destination: UserProfileView(username: post.username)) {
                    HStack(spacing: 10) {
                        Avatar(monogram: post.username, size: 34)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(post.username)
                                .font(AppFont.inter(13, .semibold))
                                .foregroundColor(.appText)
                            Text(post.title)
                                .font(AppFont.inter(11, .regular))
                                .foregroundColor(.appTextSecondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button { showMenuSheet = true } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appText)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 10)

            // Full-bleed image — tap to open the post, double-tap to like.
            ZStack {
                PostImage(post: post)
                    .frame(height: 380)
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.horizontal)
                    .clipped()
                    .background(Color.appSurface)
                    .contentShape(Rectangle())

                if showHeartBurst {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 84))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 8)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .onTapGesture(count: 2) { doubleTapLike() }
            .onTapGesture { goToDetail = true }
            .navigationDestination(isPresented: $goToDetail) {
                PostView(post: post)
            }

            // Action bar
            HStack(spacing: 18) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    post.toggleLike()
                } label: {
                    Image(systemName: post.user_liked ? "heart.fill" : "heart")
                        .foregroundColor(post.user_liked ? .appLike : .appText)
                        .symbolEffect(.bounce, value: post.user_liked)
                }

                Button { showComments = true } label: {
                    Image(systemName: "bubble.right")
                        .foregroundColor(.appText)
                }

                Button { showMenuSheet = true } label: {
                    Image(systemName: "paperplane")
                        .foregroundColor(.appText)
                }

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    session.toggleSaved(post.id)
                } label: {
                    Image(systemName: session.isSaved(post.id) ? "bookmark.fill" : "bookmark")
                        .foregroundColor(.appText)
                        .symbolEffect(.bounce, value: session.isSaved(post.id))
                }
            }
            .font(.system(size: 23, weight: .regular))
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Likes
            Text("\(post.likes >= 1000 ? "1,000+" : "\(post.likes)") likes")
                .font(AppFont.inter(13, .semibold))
                .foregroundColor(.appText)
                .padding(.horizontal, AppSpacing.md)

            // Caption: username + description
            (Text(post.username + "  ").font(AppFont.inter(13, .semibold))
             + Text(post.description).font(AppFont.inter(13, .regular)))
                .foregroundColor(.appText)
                .lineLimit(2)
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, 3)

            // View comments
            if post.numberOfComments() > 0 {
                Button { showComments = true } label: {
                    Text("View all \(post.numberOfComments()) comments")
                        .font(AppFont.inter(13, .regular))
                        .foregroundColor(.appTextSecondary)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, 3)
            }

            // Timestamp
            Text(post.time_ago().uppercased())
                .font(AppFont.inter(10, .regular))
                .foregroundColor(.appTextSecondary)
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, 4)
                .padding(.bottom, 16)
        }
        .sheet(isPresented: $showMenuSheet) { MenuSheet(post: post) }
        .sheet(isPresented: $showComments) {
            CommentSectionView(viewModel: $post.commentsModel)
        }
    }

    /// Instagram's signature interaction — double-tap the photo to like it
    /// (never unlike), with a heart burst and haptic.
    private func doubleTapLike() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if !post.user_liked {
            post.toggleLike()
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showHeartBurst = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(.easeOut(duration: 0.2)) {
                showHeartBurst = false
            }
        }
    }
}
