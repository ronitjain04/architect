//
//  ProfileView.swift
//  ARchitect
//
//  The signed-in user's profile — Instagram-style: avatar, real stats
//  (posts / followers / following), bio, and a grid of the user's actual
//  posts plus a Saved tab backed by their bookmarks.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var session: SessionStore
    @State private var selectedSection: ProfileSection = .posts
    @State private var showEditProfile = false
    @State private var showARCamera = false
    @State private var showLogOutDialog = false

    @State private var myPosts: [Post] = []
    @State private var savedPosts: [Post] = []
    @State private var followerCount = 0
    @State private var isLoading = true

    enum ProfileSection { case posts, saved }

    private var handle: String { session.profile?.username ?? "you" }
    private var displayName: String { session.profile?.displayName ?? "" }
    private var bio: String {
        let value = session.profile?.bio ?? ""
        return value.isEmpty ? "Add a bio in Edit profile" : value
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Divider().background(Color.appDivider)

                ScrollView {
                    profileHeader
                    sectionTabs
                    grid
                        .padding(.bottom, 90)
                }
                .refreshable { await reload() }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: session.profile?.username) { await reload() }
        .onChange(of: session.savedPostIDs) {
            Task { savedPosts = await SocialService.fetchPosts(ids: Array(session.savedPostIDs)) }
        }
    }

    private func reload() async {
        guard let username = session.profile?.username else { return }
        isLoading = true
        async let mine = SocialService.fetchPosts(byUsername: username)
        async let saved = SocialService.fetchPosts(ids: Array(session.savedPostIDs))
        async let followers = SocialService.followerCount(of: username)
        myPosts = await mine
        savedPosts = await saved
        followerCount = await followers
        isLoading = false
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 6) {
            Text(handle)
                .font(AppFont.inter(18, .semibold))
                .foregroundColor(.appText)
            Spacer()
            // Capture a new space in AR.
            Button { showARCamera = true } label: {
                Image(systemName: "plus.app")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(.appText)
            }
            // Account menu.
            Button { showLogOutDialog = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(.appText)
            }
            .padding(.leading, AppSpacing.sm)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 10)
        .fullScreenCover(isPresented: $showARCamera) {
            ARCaptureView()
        }
        .confirmationDialog("Account", isPresented: $showLogOutDialog) {
            Button("Log out", role: .destructive) {
                session.signOut()
            }
        }
    }

    // MARK: Header

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.lg) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.appAccent, lineWidth: 2.5)
                        .frame(width: 88, height: 88)
                    Avatar(monogram: handle, size: 78)
                }

                HStack(spacing: 0) {
                    stat(value: "\(myPosts.count)", label: "posts")
                    stat(value: "\(followerCount)", label: "followers")
                    stat(value: "\(session.following.count)", label: "following")
                }
                .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(AppFont.inter(14, .semibold))
                    .foregroundColor(.appText)
                Text(bio)
                    .font(AppFont.inter(13, .regular))
                    .foregroundColor(.appText)
            }

            HStack(spacing: AppSpacing.sm) {
                Button { showEditProfile = true } label: { Text("Edit profile") }
                    .buttonStyle(CompactSecondaryButtonStyle())
                ShareLink(item: "Check out my ARchitect profile — @\(handle)") {
                    Text("Share profile")
                }
                .buttonStyle(CompactSecondaryButtonStyle())
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.md)
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet(
                displayName: session.profile?.displayName ?? "",
                bio: session.profile?.bio ?? ""
            )
            .environmentObject(session)
        }
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

    // MARK: Section tabs

    private var sectionTabs: some View {
        HStack(spacing: 0) {
            sectionTab(.posts, icon: "square.grid.3x3")
            sectionTab(.saved, icon: "bookmark")
        }
        .overlay(Rectangle().fill(Color.appDivider).frame(height: 0.5), alignment: .top)
    }

    private func sectionTab(_ section: ProfileSection, icon: String) -> some View {
        let isSelected = selectedSection == section
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedSection = section }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .appText : .appTextSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .overlay(
                    Rectangle()
                        .fill(isSelected ? Color.appText : Color.clear)
                        .frame(height: 1.5),
                    alignment: .bottom
                )
        }
    }

    // MARK: Grid

    @ViewBuilder
    private var grid: some View {
        let posts = selectedSection == .posts ? myPosts : savedPosts

        if isLoading {
            ProgressView()
                .tint(.appPrimary)
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        } else if posts.isEmpty {
            emptyState
        } else {
            PostGrid(posts: posts)
                .padding(.top, 2)
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: selectedSection == .posts ? "camera" : "bookmark")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.appTextSecondary)
            Text(selectedSection == .posts ? "No posts yet" : "No saved posts")
                .font(AppFont.inter(16, .semibold))
                .foregroundColor(.appText)
            Text(selectedSection == .posts
                 ? "Capture a space in AR to share your first one."
                 : "Tap the bookmark on any post to save it here.")
                .font(AppFont.inter(13, .regular))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
        .padding(.horizontal, AppSpacing.xl)
    }
}

// MARK: - Shared post grid

/// Three-column square grid of posts; cells open the post detail.
struct PostGrid: View {
    let posts: [Post]

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(posts) { post in
                NavigationLink(destination: PostView(post: post)) {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(PostImage(post: post))
                        .clipped()
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Edits the profile fields and persists them to the user's Firestore
/// document.
struct EditProfileSheet: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State var displayName: String
    @State var bio: String

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Text("Edit profile")
                .font(AppFont.inter(15, .semibold))
                .foregroundColor(.appText)
                .padding(.top, AppSpacing.md)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Name")
                    .font(AppFont.inter(13, .semibold))
                    .foregroundColor(.appTextSecondary)
                AuthField(placeholder: "Name", text: $displayName)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Bio")
                    .font(AppFont.inter(13, .semibold))
                    .foregroundColor(.appTextSecondary)
                TextField("Bio", text: $bio, axis: .vertical)
                    .lineLimit(2...4)
                    .font(AppFont.body)
                    .foregroundColor(.appText)
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                            .fill(Color.appSurfaceAlt)
                    )
            }

            Button("Done") {
                Task {
                    await session.updateProfile(displayName: displayName, bio: bio)
                    dismiss()
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            Spacer()
        }
        .padding(.horizontal, AppSpacing.lg)
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appBackground)
    }
}

/// Quiet, compact tan button used for the profile's "Edit profile" / "Share".
struct CompactSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.inter(13, .semibold))
            .foregroundColor(.appText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                    .fill(Color.appSurfaceAlt)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(SessionStore())
    }
}
