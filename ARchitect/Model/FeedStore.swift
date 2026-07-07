//
//  FeedStore.swift
//  ARchitect
//
//  Live feed of posts from the Firestore "posts" collection, newest first.
//  In debug builds, seeds the collection with the bundled sample posts the
//  first time it's found empty so the feed has content to show.
//

import Foundation
import UIKit
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

    // MARK: - Create

    enum CreatePostError: LocalizedError {
        case imageEncoding
        var errorDescription: String? { "Couldn't encode the captured image." }
    }

    /// Creates the post document with the capture embedded as a compressed
    /// JPEG (Spark-plan friendly — no Storage bucket needed). The feed's
    /// snapshot listener picks it up immediately.
    ///
    /// Migration note: the read path (PostImage) also renders an `imageURL`
    /// field, so moving to Firebase Storage later only means swapping the
    /// write below for an upload + URL — old embedded posts keep working.
    static func createPost(
        image: UIImage,
        title: String,
        description: String,
        furniture: [String],
        username: String
    ) async throws {
        let data = try compressedImageData(from: image)

        try await Firestore.firestore().collection("posts").addDocument(data: [
            "username": username,
            "title": title,
            "description": description,
            "imageData": data,
            "furnitureModels": furniture,
            "createdAt": FieldValue.serverTimestamp(),
            "likedBy": [],
            "commentCount": 0,
        ])
    }

    /// Resizes to feed size and walks JPEG quality down until the bytes fit
    /// comfortably inside Firestore's 1 MB document limit.
    private static func compressedImageData(from image: UIImage, maxDimension: CGFloat = 800) throws -> Data {
        let largestSide = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / max(largestSide, 1))
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        for quality in [0.7, 0.5, 0.35, 0.2] {
            if let data = resized.jpegData(compressionQuality: quality), data.count < 850_000 {
                return data
            }
        }
        throw CreatePostError.imageEncoding
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
