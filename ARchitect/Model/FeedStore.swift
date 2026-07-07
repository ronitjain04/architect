//
//  FeedStore.swift
//  ARchitect
//
//  Live feed of posts from the Firestore "posts" collection, newest first.
//  In debug builds, seeds the collection with the bundled sample posts the
//  first time it's found empty so the feed has content to show.
//

import Foundation
import FirebaseCore
import FirebaseFirestore

@MainActor
final class FeedStore: ObservableObject {
    @Published private(set) var posts: [Post] = []
    @Published private(set) var isLoading = true

    private var listener: ListenerRegistration?
    private var didAttemptSeed = false

    func start() {
        guard listener == nil, FirebaseApp.app() != nil else {
            isLoading = false
            return
        }
        listener = Firestore.firestore().collection("posts")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    defer { self.isLoading = false }
                    guard let snapshot else { return }

                    self.posts = snapshot.documents.map {
                        Post(docID: $0.documentID, data: $0.data())
                    }

                    #if DEBUG
                    if snapshot.documents.isEmpty, !self.didAttemptSeed {
                        self.didAttemptSeed = true
                        self.seedSamplePosts()
                    }
                    #endif
                }
            }
    }

    deinit {
        listener?.remove()
    }

    #if DEBUG
    /// One-time demo content so a fresh database still shows a feed.
    private func seedSamplePosts() {
        let samples: [(username: String, title: String, asset: String, description: String, hoursAgo: Double)] = [
            ("ronit", "1990 Vintage", "ar_room1", "Bold interior design project that revives the vibrant energy of the early '80s. It marries vivid color schemes, geometric patterns, and nostalgic accents with contemporary comforts.", 2),
            ("bob", "Virtual Office", "ar_room2", "Reimagined my home office in AR before buying a single piece — the desk placement made all the difference.", 5),
            ("sam", "Sunlit Corner", "ar_room3", "My own room with amazing lighting and furniture. Explore how I have transformed my space.", 9),
            ("paul", "Reading Nook", "ar_room4", "Tried three different armchairs in AR and kept the one that fit the corner best.", 14),
            ("maya", "Warm Minimal", "ar_room5", "Less furniture, more light. AR made it easy to see what to remove.", 20),
            ("steven", "Cozy Loft", "ar_room6", "My own room with amazing lighting and furniture. Explore how I have transformed my space.", 28),
            ("ana", "Gallery Wall", "ar_room7", "Previewed the whole gallery wall in AR before hammering a single nail.", 36),
        ]

        let db = Firestore.firestore()
        for sample in samples {
            db.collection("posts").addDocument(data: [
                "username": sample.username,
                "title": sample.title,
                "description": sample.description,
                "imageAsset": sample.asset,
                "createdAt": Timestamp(date: Date().addingTimeInterval(-sample.hoursAgo * 3600)),
                "likedBy": [],
                "commentCount": 0,
            ])
        }
    }
    #endif
}
