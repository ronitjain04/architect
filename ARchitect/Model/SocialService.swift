//
//  SocialService.swift
//  ARchitect
//
//  One-shot Firestore queries for the social layer: profiles by username,
//  a user's posts, saved posts by ID, follower counts, and people search.
//  Usernames are the join key between posts and profiles (they're set at
//  signup and not editable).
//

import Foundation
import FirebaseFirestore

/// A user profile as visible to others.
struct PublicUser {
    let profile: UserProfile
    let followingCount: Int
}

enum SocialService {
    /// The public profile for a username, or nil if no account exists
    /// (e.g. seeded demo authors).
    static func fetchUser(username: String) async -> PublicUser? {
        let snapshot = try? await Firestore.firestore().collection("users")
            .whereField("username", isEqualTo: username)
            .limit(to: 1)
            .getDocuments()
        guard let data = snapshot?.documents.first?.data() else { return nil }
        return PublicUser(
            profile: UserProfile(
                username: data["username"] as? String ?? username,
                displayName: data["displayName"] as? String ?? "",
                bio: data["bio"] as? String ?? ""
            ),
            followingCount: (data["following"] as? [String])?.count ?? 0
        )
    }

    /// All posts by a username, newest first. Sorted client-side so no
    /// composite index is needed.
    static func fetchPosts(byUsername username: String) async -> [Post] {
        let snapshot = try? await Firestore.firestore().collection("posts")
            .whereField("username", isEqualTo: username)
            .getDocuments()
        let posts = (snapshot?.documents ?? []).map {
            Post(docID: $0.documentID, data: $0.data())
        }
        return posts.sorted { $0.timeAgo > $1.timeAgo }
    }

    /// Posts for a set of document IDs (bookmarks), newest first.
    /// Firestore caps `in` queries, so fetch in chunks.
    static func fetchPosts(ids: [String]) async -> [Post] {
        guard !ids.isEmpty else { return [] }
        var posts: [Post] = []
        for chunk in stride(from: 0, to: ids.count, by: 10).map({ Array(ids[$0..<min($0 + 10, ids.count)]) }) {
            let snapshot = try? await Firestore.firestore().collection("posts")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            posts.append(contentsOf: (snapshot?.documents ?? []).map {
                Post(docID: $0.documentID, data: $0.data())
            })
        }
        return posts.sorted { $0.timeAgo > $1.timeAgo }
    }

    /// How many users follow this username (server-side aggregate).
    static func followerCount(of username: String) async -> Int {
        let query = Firestore.firestore().collection("users")
            .whereField("following", arrayContains: username)
            .count
        let snapshot = try? await query.getAggregation(source: .server)
        return snapshot.map { Int(truncating: $0.count) } ?? 0
    }

    /// Username prefix search.
    static func searchUsers(prefix: String) async -> [UserProfile] {
        let term = prefix.lowercased()
        guard !term.isEmpty else { return [] }
        let snapshot = try? await Firestore.firestore().collection("users")
            .whereField("username", isGreaterThanOrEqualTo: term)
            .whereField("username", isLessThan: term + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments()
        return (snapshot?.documents ?? []).map { doc in
            let data = doc.data()
            return UserProfile(
                username: data["username"] as? String ?? "",
                displayName: data["displayName"] as? String ?? "",
                bio: data["bio"] as? String ?? ""
            )
        }
    }

    /// Deletes a post document (rules enforce author-only).
    static func deletePost(_ post: Post) async throws {
        guard let docID = post.docID else { return }
        try await Firestore.firestore().collection("posts").document(docID).delete()
    }
}
