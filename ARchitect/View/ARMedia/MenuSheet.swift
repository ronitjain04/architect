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
    @State private var confirmDelete = false

    /// Measured height of the sheet's content, fed back into the detent so
    /// the sheet hugs its rows instead of guessing a fixed height (guessed
    /// heights left a large dead zone under the last row).
    @State private var contentHeight: CGFloat = 220

    private var isOwnPost: Bool {
        session.profile?.username == post.username
    }

    var body: some View {
        VStack(spacing: 0) {
            ShareLink(item: "Check out \(post.username)'s space “\(post.title)” on ARchitect") {
                rowLabel(icon: "square.and.arrow.up", label: "Share this post")
                    .foregroundColor(.appText)
            }

            Divider().background(Color.appDivider).padding(.leading, 56)

            row(icon: session.isSaved(post.id) ? "bookmark.fill" : "bookmark",
                label: session.isSaved(post.id) ? "Unsave post" : "Save post") {
                session.toggleSaved(post.id)
                dismiss()
            }

            if isOwnPost {
                Divider().background(Color.appDivider).padding(.leading, 56)

                Button {
                    confirmDelete = true
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
        .onPreferenceChange(MenuSheetHeightKey.self) { contentHeight = $0 }
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appBackground)
        .confirmationDialog("Delete this post?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await SocialService.deletePost(post)
                    dismiss()
                }
            }
        } message: {
            Text("This can't be undone.")
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
