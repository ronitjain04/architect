//
//  ActivityStore.swift
//  ARchitect
//
//  Live feed of the signed-in user's notifications from
//  users/{uid}/notifications, newest first. Capped at 50 — no pagination
//  exists anywhere else in the app yet, so a simple limit matches current
//  conventions.
//

import Foundation
import FirebaseCore
import FirebaseFirestore

@MainActor
final class ActivityStore: ObservableObject {
    @Published private(set) var notifications: [AppNotification] = []
    @Published private(set) var isLoading = true

    private var listener: ListenerRegistration?

    func start(uid: String) {
        guard listener == nil, FirebaseApp.app() != nil else {
            isLoading = false
            return
        }
        listener = Firestore.firestore()
            .collection("users").document(uid)
            .collection("notifications")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    defer { self.isLoading = false }
                    guard let snapshot else { return }

                    self.notifications = snapshot.documents.compactMap { doc -> AppNotification? in
                        let data = doc.data()
                        guard let type = AppNotification.NotificationType(rawValue: data["type"] as? String ?? "") else {
                            return nil
                        }
                        return AppNotification(
                            id: doc.documentID,
                            type: type,
                            actorUsername: data["actorUsername"] as? String ?? "",
                            postID: data["postID"] as? String,
                            read: data["read"] as? Bool ?? false,
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                        )
                    }
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
        notifications = []
    }

    func markRead(_ notification: AppNotification, uid: String) {
        NotificationService.markRead(uid: uid, notificationID: notification.id)
    }

    deinit {
        listener?.remove()
    }
}
