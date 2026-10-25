//
//  NewPostView.swift
//  ARchitect
//
//  The "New post" composer — replaces the UIKit ScreenshotViewController.
//  Shows the captured AR snapshot, takes a title + caption, and shares it:
//  compact preview and room data to Firestore. The live feed
//  listener picks it up immediately.
//

import SwiftUI

struct NewPostView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    let image: UIImage
    let usedFurniture: [String]
    var experience: RoomExperience? = nil
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
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.appText)
                    }

                    .disabled(isUploading)
                    Spacer()

                    Text("Share your room")
                        .font(AppFont.headline)
                        .foregroundColor(.appText)

                    Spacer()
                    Color.clear.frame(width: 17, height: 17)
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 48)

                Divider().background(Color.appDivider)

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 280)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))

                        Text("This is the preview people will see.")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.appTextSecondary)

                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Room title").font(AppFont.headline).foregroundStyle(Color.appText)
                            AuthField(placeholder: "e.g. Sunlit living room", text: $title)
                        }

                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Caption (optional)").font(AppFont.headline).foregroundStyle(Color.appText)
                            TextField("What inspired this space?", text: $caption, axis: .vertical)
                                .lineLimit(3...6)
                                .font(AppFont.body)
                                .foregroundColor(.appText)
                                .padding(AppSpacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                        .fill(Color.appSurfaceAlt)
                                )
                        }

                        if !usedFurniture.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Furniture in this post")
                                    .font(AppFont.inter(13, .semibold))
                                    .foregroundColor(.appTextSecondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: AppSpacing.sm) {
                                        ForEach(Array(Set(usedFurniture)).sorted(), id: \.self) { name in
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

                        if experience != nil {
                            Label("Your room scan and furniture will be visible to signed-in beta testers.", systemImage: "person.2")
                                .font(AppFont.caption)
                                .foregroundStyle(Color.appTextSecondary)
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

                Button(action: share) {
                    HStack {
                        if isUploading { ProgressView().tint(.appOnPrimary) }
                        Text(isUploading ? "Sharing your room…" : "Share room")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isUploading)
                .padding(AppSpacing.md)
                .background(Color.appBackground)
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
                    experience: experience,
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
