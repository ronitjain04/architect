//
//  PostModel.swift
//  ARchitect
//
//  A feed post. Backed by a document in the Firestore "posts" collection when
//  docID is set; posts constructed without one behave as local, in-memory
//  sample data (used by previews).
//
//  Firestore schema — posts/{id}:
//    username, title, description: String
//    imageAsset: String?   (bundled asset name — seeded demo posts)
//    imageData: Data?      (embedded compressed JPEG — user-created posts)
//    imageURL: String?     (Storage download URL — future migration path)
//    createdAt: Timestamp
//    likedBy: [uid]
//    commentCount: Int
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class Post: ObservableObject, Identifiable {
    /// Stable identity: the Firestore document ID when remote, else a UUID.
    var id: String { docID ?? uuid.uuidString }
    let uuid = UUID()
    let docID: String?

    let username: String
    let userImage: String
    let title: String
    let imageName: String
    let imageURL: String?
    let imageData: Data?
    let description: String
    let authorUid: String
    let timeAgo: Date
    @Published var likes: Int
    @Published var user_liked: Bool
    @Published var commentsModel: CommentViewModel

    // MARK: - Firestore

    init(docID: String, data: [String: Any]) {
        self.docID = docID
        self.username = data["username"] as? String ?? "user"
        self.userImage = "person.circle.fill"
        self.title = data["title"] as? String ?? ""
        self.imageName = data["imageAsset"] as? String ?? ""
        self.imageURL = data["imageURL"] as? String
        self.imageData = data["imageData"] as? Data
        self.description = data["description"] as? String ?? ""
        self.authorUid = data["authorUid"] as? String ?? ""
        self.timeAgo = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        let likedBy = data["likedBy"] as? [String] ?? []
        self.likes = likedBy.count
        self.user_liked = Auth.auth().currentUser.map { likedBy.contains($0.uid) } ?? false
        self.commentCount = data["commentCount"] as? Int ?? 0
        self.commentsModel = CommentViewModel(postDocID: docID)
    }

    /// Denormalized comment count from the post document; the live list loads
    /// only when the comments sheet opens.
    @Published var commentCount: Int

    // MARK: - Local / preview initializers

    init(username: String, userImage: String, title: String, imageName: String, description: String, likes: Int, user_liked: Bool = false, commentsModel: CommentViewModel = CommentViewModel()) {
        self.docID = nil
        self.username = username
        self.userImage = userImage
        self.title = title
        self.imageName = imageName
        self.imageURL = nil
        self.imageData = nil
        self.description = description
        self.authorUid = ""
        self.timeAgo = Date()
        self.likes = likes
        self.user_liked = user_liked
        self.commentCount = 0
        self.commentsModel = commentsModel
    }

    init(imageName: String) {
        self.docID = nil
        self.username = "username"
        self.userImage = "person.circle.fill"
        self.title = "1990 Vintage"
        self.imageName = imageName
        self.imageURL = nil
        self.imageData = nil
        self.description = "Lengthy description about the furniture and the positioning of different elements that were used."
        self.authorUid = ""
        self.timeAgo = Date()
        self.likes = 80
        self.user_liked = false
        self.commentCount = 0
        self.commentsModel = CommentViewModel()
    }

    // MARK: - Actions

    /// Optimistic local flip; persists to the post document when remote.
    func toggleLike() {
        if user_liked {
            likes = max(likes - 1, 0)
        } else {
            likes += 1
        }
        user_liked.toggle()

        guard let docID, let uid = Auth.auth().currentUser?.uid else { return }
        let update = user_liked
            ? FieldValue.arrayUnion([uid])
            : FieldValue.arrayRemove([uid])
        Firestore.firestore().collection("posts").document(docID)
            .updateData(["likedBy": update])
    }

    func addComment(text: String, publisher: String) {
        commentsModel.addComment(text: text, publisher: publisher)
        commentCount += 1
    }

    func time_ago() -> String {
        let time_diff = Date().timeIntervalSince(timeAgo)

        if time_diff < 5 {
            return "Just now"
        } else if time_diff < 60 {
            return "\(Int(time_diff)) seconds ago"
        } else if time_diff < 3600 {
            return "\(Int(time_diff/60)) minutes ago"
        } else if time_diff < 86400 {
            return "\(Int(time_diff/60/60)) hours ago"
        } else {
            return "\(Int(time_diff/60/60/24)) days ago"
        }
    }

    func numberOfComments() -> Int {
        max(commentCount, commentsModel.length())
    }
}
