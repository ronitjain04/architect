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
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(isOwnPost ? 230 : 170)])
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
