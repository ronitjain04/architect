//
//  MenuSheet.swift
//  ARchitect
//
//  Post options — a compact Instagram-style action sheet with full-width
//  icon rows.
//

import SwiftUI

struct MenuSheet: View {
    var post: Post
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            row(icon: "square.and.arrow.up", label: "Share this post") {
                dismiss()
            }
            Divider().background(Color.appDivider).padding(.leading, 56)

            row(icon: "eye.slash", label: "Hide this post") {
                dismiss()
            }
            Divider().background(Color.appDivider).padding(.leading, 56)

            row(icon: "person.circle", label: "Go to profile") {
                dismiss()
            }
        }
        .padding(.top, AppSpacing.md)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appBackground)
    }

    private func row(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .frame(width: 28)
                Text(label)
                    .font(AppFont.inter(15, .regular))
                Spacer()
            }
            .foregroundColor(.appText)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
    }
}

#Preview {
    MenuSheet(
        post: Post(
            username: "username",
            userImage: "person.circle.fill", // SF Symbol for user avatar
            title: "1990 Vintage",
            imageName: "ar_room1", // Replace with actual asset name
            description: "Bold interior design project that revives the vibrant energy of the early '80s. It marries vivid color schemes, geometric patterns, and nostalgic accents with contemporary comforts.",
            likes: 120)
    )
}
