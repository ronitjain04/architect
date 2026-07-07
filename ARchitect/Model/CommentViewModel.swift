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

    private let postDocID: String?
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
    }

    /// Comments backed by posts/{postDocID}/comments.
    init(postDocID: String?) {
        self.postDocID = postDocID
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

    func addComment(text: String, publisher: String) {
        if let postDocID, FirebaseApp.app() != nil {
            let post = Firestore.firestore().collection("posts").document(postDocID)
            post.collection("comments").addDocument(data: [
                "authorUid": Auth.auth().currentUser?.uid ?? "",
                "text": text,
                "publisher": publisher,
                "timestamp": FieldValue.serverTimestamp(),
            ])
            post.updateData(["commentCount": FieldValue.increment(Int64(1))])
            // The listener delivers the new comment; nothing to append locally.
        } else {
            comments.append(Comment(
                id: UUID().uuidString,
                text: text,
                timestamp: Date(),
                publisher: publisher
            ))
        }
    }

    func length() -> Int {
        return comments.count
    }
}
