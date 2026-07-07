import SwiftUI

/// Instagram-style comments sheet: a titled header, comment rows with
/// avatars, and an input bar pinned to the bottom.
struct CommentSectionView: View {
    @Binding var viewModel: CommentViewModel

    var body: some View {
        // The class is handed down as a binding from Post; observe it in an
        // inner view so newly posted comments actually refresh the list.
        CommentSheetContent(model: viewModel)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.appBackground)
    }
}

private struct CommentSheetContent: View {
    @ObservedObject var model: CommentViewModel
    @State private var newCommentText = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text("Comments")
                .font(AppFont.inter(15, .semibold))
                .foregroundColor(.appText)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm + 4)

            Divider().background(Color.appDivider)

            if model.comments.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    Text("No comments yet")
                        .font(AppFont.inter(17, .semibold))
                        .foregroundColor(.appText)
                    Text("Start the conversation.")
                        .font(AppFont.inter(13, .regular))
                        .foregroundColor(.appTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppSpacing.md + 4) {
                        ForEach(model.comments) { comment in
                            CommentRow(comment: comment)
                        }
                    }
                    .padding(AppSpacing.md)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            Divider().background(Color.appDivider)

            // Input bar
            HStack(spacing: AppSpacing.sm + 2) {
                Avatar(monogram: "M", size: 34)

                TextField("Add a comment…", text: $newCommentText)
                    .font(AppFont.body)
                    .foregroundColor(.appText)
                    .padding(.horizontal, AppSpacing.md)
                    .frame(height: 40)
                    .background(Capsule().fill(Color.appSurfaceAlt))
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit(postComment)

                Button(action: postComment) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(newCommentText.isEmpty ? .appTextSecondary : .appAccent)
                }
                .disabled(newCommentText.isEmpty)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm + 2)
        }
    }

    private func postComment() {
        let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        model.addComment(text: text, publisher: "myhome")
        newCommentText = ""
    }
}

private struct CommentRow: View {
    let comment: CommentViewModel.Comment

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm + 2) {
            Avatar(systemImage: comment.userImage, size: 34)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(comment.publisher)
                        .font(AppFont.inter(13, .semibold))
                        .foregroundColor(.appText)
                    Text(timeAgo)
                        .font(AppFont.inter(12, .regular))
                        .foregroundColor(.appTextSecondary)
                }
                Text(comment.text)
                    .font(AppFont.inter(14, .regular))
                    .foregroundColor(.appText)
            }

            Spacer(minLength: 0)
        }
    }

    private var timeAgo: String {
        guard Date().timeIntervalSince(comment.timestamp) >= 60 else { return "now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: comment.timestamp, relativeTo: Date())
    }
}

#Preview {
    @Previewable @State var commentViewModel = CommentViewModel()

    CommentSectionView(viewModel: $commentViewModel)
}
