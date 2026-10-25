import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Social safety actions backed by the configured Firestore project.
enum AccountSafetyService {
    static func report(post: Post, reason: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid, let postID = post.docID else {
            throw SafetyError.notSignedIn
        }
        try await Firestore.firestore().collection("reports").addDocument(data: [
            "reporterUid": uid, "postID": postID, "authorUid": post.authorUid,
            "reason": reason, "createdAt": FieldValue.serverTimestamp()
        ])
    }

    static func requestDeletion() async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw SafetyError.notSignedIn }
        let ref = Firestore.firestore().collection("deletionRequests").document(uid)
        // A repeat tap must not reset the original request timestamp.
        if try await ref.getDocument().exists { return }
        try await ref.setData(["uid": uid, "status": "pending", "createdAt": FieldValue.serverTimestamp()])
    }

    enum SafetyError: LocalizedError {
        case notSignedIn
        var errorDescription: String? { "Sign in to complete this action." }
    }
}
