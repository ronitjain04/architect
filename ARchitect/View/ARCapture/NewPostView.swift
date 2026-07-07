//
//  NewPostView.swift
//  ARchitect
//
//  The "New post" composer — replaces the UIKit ScreenshotViewController.
//  Shows the captured AR snapshot, takes a title + caption, and shares it:
//  image to Firebase Storage, post document to Firestore. The live feed
//  listener picks it up immediately.
//

import SwiftUI

struct NewPostView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    let image: UIImage
    let usedFurniture: [String]
    /// Called after a successful share; the presenter dismisses the whole
    /// capture flow back to the feed.
    var onShared: () -> Void

    @State private var title: String = ""
    @State private var caption: String = ""
    @State private var isUploading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: cancel / title / share
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.appText)
                    }

                    Spacer()

                    Text("New post")
                        .font(AppFont.inter(15, .semibold))
                        .foregroundColor(.appText)

                    Spacer()

                    Button {
                        share()
                    } label: {
                        if isUploading {
                            ProgressView().tint(.appAccent)
                        } else {
                            Text("Share")
                                .font(AppFont.inter(15, .semibold))
                                .foregroundColor(.appAccent)
                        }
                    }
                    .disabled(isUploading)
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 48)

                Divider().background(Color.appDivider)

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 300)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))

                        AuthField(placeholder: "Title (e.g. Sunlit Living Room)", text: $title)

                        TextField("Write a caption…", text: $caption, axis: .vertical)
                            .lineLimit(3...6)
                            .font(AppFont.body)
                            .foregroundColor(.appText)
                            .padding(AppSpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                    .fill(Color.appSurfaceAlt)
                            )

                        if !usedFurniture.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Furniture in this post")
                                    .font(AppFont.inter(13, .semibold))
                                    .foregroundColor(.appTextSecondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: AppSpacing.sm) {
                                        ForEach(usedFurniture, id: \.self) { name in
                                            Text(name.capitalized)
                                                .font(AppFont.inter(12, .semibold))
                                                .foregroundColor(.white)
                                                .padding(.vertical, 5)
                                                .padding(.horizontal, 12)
                                                .background(Capsule().fill(Color.appAccent))
                                        }
                                    }
                                }
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(AppFont.inter(12, .medium))
                                .foregroundColor(.appLike)
                        }
                    }
                    .padding(AppSpacing.md)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .interactiveDismissDisabled(isUploading)
    }

    private func share() {
        errorMessage = nil
        isUploading = true
        Task {
            do {
                try await FeedStore.createPost(
                    image: image,
                    title: title.isEmpty ? "Untitled space" : title,
                    description: caption,
                    furniture: usedFurniture,
                    username: session.profile?.username ?? "you"
                )
                onShared()
            } catch {
                errorMessage = error.localizedDescription
                isUploading = false
            }
        }
    }
}

#Preview {
    NewPostView(
        image: UIImage(systemName: "photo")!,
        usedFurniture: ["Curved Comfort Chair"],
        onShared: {}
    )
    .environmentObject(SessionStore())
}
