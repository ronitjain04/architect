//
//  NotificationService.swift
//  ARchitect
//
//  Writes and reads for the in-app activity feed: likes, comments, and
//  follows notify their recipient via a users/{uid}/notifications
//  subcollection. Likes and follows are current-state facts (mirroring
//  likedBy/following), so they use deterministic doc IDs and are deleted
//  on unlike/unfollow rather than accumulating. Comments are an
//  append-only log, so each comment gets its own auto-ID notification.
//

import Foundation
import FirebaseFirestore

/// A single activity-feed entry, addressed to the signed-in user.
struct AppNotification: Identifiable {
    enum NotificationType: String {
        case like
        case comment
        case follow
    }

    let id: String
    let type: NotificationType
    let actorUsername: String
    let postID: String?
    let read: Bool
    let createdAt: Date
}

enum NotificationService {
    private static func notifications(for uid: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(uid).collection("notifications")
    }

    // MARK: - Like

    static func writeLike(recipientUid: String, actorUid: String, actorUsername: String, postID: String) {
        guard actorUid != recipientUid, !recipientUid.isEmpty else { return }
        notifications(for: recipientUid).document("like_\(postID)_\(actorUsername)").setData([
            "type": AppNotification.NotificationType.like.rawValue,
            "actorUsername": actorUsername,
            "postID": postID,
            "read": false,
            "createdAt": FieldValue.serverTimestamp(),
        ])
    }

    static func deleteLike(recipientUid: String, actorUsername: String, postID: String) {
        guard !recipientUid.isEmpty else { return }
        notifications(for: recipientUid).document("like_\(postID)_\(actorUsername)").delete()
    }

    // MARK: - Comment

    static func writeComment(recipientUid: String, actorUid: String, actorUsername: String, postID: String) {
        guard actorUid != recipientUid, !recipientUid.isEmpty else { return }
        notifications(for: recipientUid).addDocument(data: [
            "type": AppNotification.NotificationType.comment.rawValue,
            "actorUsername": actorUsername,
            "postID": postID,
            "read": false,
            "createdAt": FieldValue.serverTimestamp(),
        ])
    }

    // MARK: - Follow

    static func writeFollow(recipientUid: String, actorUid: String, actorUsername: String) {
        guard actorUid != recipientUid, !recipientUid.isEmpty else { return }
        notifications(for: recipientUid).document("follow_\(actorUsername)").setData([
            "type": AppNotification.NotificationType.follow.rawValue,
            "actorUsername": actorUsername,
            "postID": NSNull(),
            "read": false,
            "createdAt": FieldValue.serverTimestamp(),
        ])
    }

    static func deleteFollow(recipientUid: String, actorUsername: String) {
        guard !recipientUid.isEmpty else { return }
        notifications(for: recipientUid).document("follow_\(actorUsername)").delete()
    }

    // MARK: - Read

    /// Server-side aggregate count of unread notifications, for the bell badge.
    static func unreadCount(uid: String) async -> Int {
        let query = notifications(for: uid).whereField("read", isEqualTo: false).count
        let snapshot = try? await query.getAggregation(source: .server)
        return snapshot.map { Int(truncating: $0.count) } ?? 0
    }

    static func markRead(uid: String, notificationID: String) {
        notifications(for: uid).document(notificationID).updateData(["read": true])
    }
}
