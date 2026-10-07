//
//  CommentViewModel.swift
//  ARchitect
//
//  Comments for a post. Backed by the posts/{id}/comments subcollection when
//  a post document ID is provided; otherwise a purely local list (previews).
//  The live listener starts lazily when the comments sheet first opens.
//

import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

class CommentViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var errorMessage: String?
    @Published var isSending = false

    private let postDocID: String?
    private let postAuthorUid: String
    private var listener: ListenerRegistration?

    struct Comment: Identifiable {
        let id: String
        let userImage: String = "person.circle.fill"
        let text: String
        let timestamp: Date
        let publisher: String
    }

    /// Local, in-memory comments (previews and sample posts).
    init() {
        postDocID = nil
        postAuthorUid = ""
    }

    /// Comments backed by posts/{postDocID}/comments.
    init(postDocID: String?, postAuthorUid: String = "") {
        self.postDocID = postDocID
        self.postAuthorUid = postAuthorUid
    }

    deinit {
        listener?.remove()
    }

    /// Attach the Firestore listener; safe to call repeatedly.
    func startObserving() {
        guard listener == nil, let postDocID, FirebaseApp.app() != nil else { return }
        listener = Firestore.firestore()
            .collection("posts").document(postDocID)
            .collection("comments")
            .order(by: "timestamp")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let snapshot else { return }
                let loaded = snapshot.documents.map { doc -> Comment in
                    let data = doc.data()
                    return Comment(
                        id: doc.documentID,
                        text: data["text"] as? String ?? "",
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                        publisher: data["publisher"] as? String ?? "user"
                    )
                }
                DispatchQueue.main.async {
                    self?.comments = loaded
                }
            }
    }

    @MainActor
    func addComment(text: String, publisher: String) async -> Bool {
        guard !isSending, !text.isEmpty, text.count <= 2000,
              let postDocID, let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Sign in and enter a comment of 1–2,000 characters."
            return false
        }
        isSending = true
        defer { isSending = false }
        do {
            let db = Firestore.firestore()
            let post = db.collection("posts").document(postDocID)
            let comment = post.collection("comments").document()
            let batch = db.batch()
            batch.setData(["authorUid": uid, "text": text, "publisher": publisher,
                           "timestamp": FieldValue.serverTimestamp()], forDocument: comment)
            batch.updateData(["commentCount": FieldValue.increment(Int64(1)),
                              "lastCommentID": comment.documentID], forDocument: post)
            try await batch.commit()
            NotificationService.writeComment(recipientUid: postAuthorUid, actorUid: uid,
                actorUsername: publisher, postID: postDocID, commentID: comment.documentID)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func length() -> Int {
        return comments.count
    }
}
