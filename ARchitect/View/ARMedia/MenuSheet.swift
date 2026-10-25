//
//  MenuSheet.swift
//  ARchitect
//
//  Post options — a compact Instagram-style action sheet: share, save, and
//  (for your own posts) delete.
//

import SwiftUI

struct MenuSheet: View {
    @EnvironmentObject var session: SessionStore
    @ObservedObject var post: Post
    @Environment(\.dismiss) private var dismiss
    @State private var activeDialog: MenuDialog?
    @State private var feedback: Feedback?

    private enum MenuDialog { case report, delete }
    private enum Feedback {
        case reported, deleteError(String), reportError(String)
        var title: String {
            switch self {
            case .reported: "Report post"
            case .deleteError: "Could not delete post"
            case .reportError: "Could not report post"
            }
        }
        var message: String {
            switch self {
            case .reported: "Thanks. This post has been sent for review."
            case .deleteError(let message), .reportError(let message): message
            }
        }
    }

    /// Measured height of the sheet's content, fed back into the detent so
    /// the sheet hugs its rows instead of guessing a fixed height (guessed
    /// heights left a large dead zone under the last row). Zero until the
    /// first measurement lands; the detent falls back to the estimate below.
    @State private var contentHeight: CGFloat = 0

    private var isOwnPost: Bool {
        session.user?.uid == post.authorUid
    }

    /// First-frame estimate keyed to the row count (row ≈ 56pt: 16+16
    /// vertical padding + ~24pt label) so the sheet opens at roughly its
    /// final size and the measured correction is imperceptible — a fixed
    /// seed made the 2-row sheet visibly shrink ~60pt after presenting.
    private var estimatedContentHeight: CGFloat {
        AppSpacing.md + CGFloat(isOwnPost ? 3 : 4) * 56 + 28
    }

    var body: some View {
        VStack(spacing: 0) {
            ShareLink(item: RoomLink.url(postID: post.id)?.absoluteString ?? post.title) {
                rowLabel(icon: "square.and.arrow.up", label: "Share this post")
                    .foregroundColor(.appText)
            }

            Divider().background(Color.appDivider).padding(.leading, 56)

            row(icon: session.isSaved(post.id) ? "bookmark.fill" : "bookmark",
                label: session.isSaved(post.id) ? "Unsave post" : "Save post") {
                session.toggleSaved(post.id)
                dismiss()
            }

            if !isOwnPost {
                Divider().background(Color.appDivider).padding(.leading, 56)
                row(icon: "flag", label: "Report post") { activeDialog = .report }
                Divider().background(Color.appDivider).padding(.leading, 56)
                row(icon: "hand.raised", label: "Block this user") {
                    Task { if await session.block(post.authorUid) { dismiss() } }
                }
            }

            if isOwnPost {
                Divider().background(Color.appDivider).padding(.leading, 56)

                Button {
                    activeDialog = .delete
                } label: {
                    rowLabel(icon: "trash", label: "Delete post")
                        .foregroundColor(.appLike)
                }
            }
        }
        .padding(.top, AppSpacing.md)
        .padding(.bottom, 28)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: MenuSheetHeightKey.self, value: proxy.size.height)
            }
        )
        // Pin the rows to the sheet's TRUE bottom edge (ignoring the home
        // indicator inset) so the 28pt padding above is the entire gap —
        // regardless of any extra height the system gives the sheet.
        .frame(maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(.container, edges: .bottom)
        .onPreferenceChange(MenuSheetHeightKey.self) { height in
            // Ignore transient zero/degenerate values (e.g. during
            // teardown) — .height(0) would collapse the sheet to a sliver.
            if height > 50 { contentHeight = height }
        }
        .presentationDetents([.height(contentHeight > 0 ? contentHeight : estimatedContentHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appBackground)
        .alert(feedback?.title ?? "", isPresented: Binding(
            get: { feedback != nil }, set: { if !$0 { feedback = nil } }
        )) {
            Button("OK") { if case .reported = feedback { dismiss() }; feedback = nil }
        } message: { Text(feedback?.message ?? "") }
        .confirmationDialog(activeDialog == .report ? "Why are you reporting this post?" : "Delete this post?",
                            isPresented: Binding(get: { activeDialog != nil }, set: { if !$0 { activeDialog = nil } }),
                            titleVisibility: .visible) {
            if activeDialog == .report {
                ForEach(["Harassment", "Inappropriate content", "Spam", "Other"], id: \.self) { reason in
                    Button(reason) {
                        activeDialog = nil
                        Task {
                            do { try await AccountSafetyService.report(post: post, reason: reason); feedback = .reported }
                            catch { feedback = .reportError(error.localizedDescription) }
                        }
                    }
                }
            } else {
                Button("Delete", role: .destructive) {
                    activeDialog = nil
                    Task {
                        do {
                            try await SocialService.deletePost(post)
                            dismiss()
                            NotificationCenter.default.post(name: .ownPostDeleted, object: nil)
                        } catch { feedback = .deleteError(error.localizedDescription) }
                    }
                }
            }
        } message: {
            if activeDialog == .delete { Text("This can't be undone.") }
        }
    }

    private func row(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowLabel(icon: icon, label: label)
                .foregroundColor(.appText)
        }
    }

    private func rowLabel(icon: String, label: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .frame(width: 28)
            Text(label)
                .font(AppFont.inter(15, .regular))
            Spacer()
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}

/// Reports the menu content's measured height up to the detent.
private struct MenuSheetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    MenuSheet(
        post: Post(
            username: "username",
            userImage: "person.circle.fill", // SF Symbol for user avatar
            title: "1990 Vintage",
            imageName: "ar_room1", // Replace with actual asset name
            description: "Bold interior design project that revives the vibrant energy of the early '80s.",
            likes: 120)
    )
    .environmentObject(SessionStore())
}
