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
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

@MainActor
final class FeedStore: ObservableObject {
    @Published private(set) var posts: [Post] = []
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    @Published private(set) var canLoadMore = false
    @Published private(set) var loadingMore = false
    private var lastDocument: DocumentSnapshot?
    private var olderPosts: [Post] = []

    private var listener: ListenerRegistration?

    func start() {
        guard listener == nil, FirebaseApp.app() != nil else {
            isLoading = false
            return
        }
        listener = Firestore.firestore().collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: 10)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    defer { self.isLoading = false }
                    if let error { self.errorMessage = error.localizedDescription; return }
                    guard let snapshot else { return }
                    self.errorMessage = nil
                    let newest = snapshot.documents.map { Post(docID: $0.documentID, data: $0.data()) }
                    let currentIDs = Set(newest.map(\.id))
                    // A new head item pushes the previous tenth item out of the live
                    // window. Retain displaced items so the pagination cursor cannot skip them.
                    if let boundary = newest.last?.timeAgo {
                        let knownTailIDs = Set(self.olderPosts.map(\.id))
                        let displaced = self.posts.filter {
                            !currentIDs.contains($0.id) && !knownTailIDs.contains($0.id) && $0.timeAgo <= boundary
                        }
                        self.olderPosts += displaced
                    }
                    self.olderPosts = self.olderPosts.filter { !currentIDs.contains($0.id) }
                        .sorted { $0.timeAgo > $1.timeAgo }
                    self.posts = newest + self.olderPosts
                    if self.olderPosts.isEmpty {
                        self.lastDocument = snapshot.documents.last
                        self.canLoadMore = snapshot.documents.count == 10
                    }


                }
            }
    }

    /// Detach the current listener and attach a fresh one. Needed after auth
    /// changes: a listener that attached before sign-in is permanently denied
    /// once security rules require a signed-in user.
    func restart() {
        listener?.remove()
        listener = nil
        isLoading = true
        olderPosts = []
        posts = []
        lastDocument = nil
        canLoadMore = false
        start()
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        posts = []
        olderPosts = []
        lastDocument = nil
    }

    func loadMore() async {
        guard let lastDocument, canLoadMore, !loadingMore else { return }
        loadingMore = true
        defer { loadingMore = false }
        do {
            let snapshot = try await Firestore.firestore().collection("posts")
                .order(by: "createdAt", descending: true).start(afterDocument: lastDocument)
                .limit(to: 10).getDocuments()
            let ids = Set(posts.map(\.id))
            let additional = snapshot.documents.map { Post(docID: $0.documentID, data: $0.data()) }.filter { !ids.contains($0.id) }
            olderPosts += additional
            posts += additional
            self.lastDocument = snapshot.documents.last
            canLoadMore = snapshot.documents.count == 10
        } catch { errorMessage = error.localizedDescription }
    }

    deinit {
        listener?.remove()
    }

    // MARK: - Create

    enum CreatePostError: LocalizedError {
        case imageEncoding
        case notSignedIn

        var errorDescription: String? {
            switch self {
            case .imageEncoding: return "Couldn't encode the captured image."
            case .notSignedIn: return "You need to be signed in to share a post."
            }
        }
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
        experience: RoomExperience? = nil,
        username: String
    ) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw CreatePostError.notSignedIn
        }
        let data = try compressedImageData(from: image)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, trimmedTitle.count <= 100, description.count <= 2000 else {
            throw PostInputError.invalidText
        }
        var fields: [String: Any] = [
            "authorUid": uid,
            "username": username,
            "title": trimmedTitle,
            "description": description,
            "imageData": data,
            "furnitureModels": furniture,
            "createdAt": FieldValue.serverTimestamp(),
            "likedBy": [],
            "commentCount": 0,
        ]
        let db = Firestore.firestore()
        let ref = db.collection("posts").document()
        let batch = db.batch()
        if let experience {
            _ = try experience.validatedRoom()
            fields["hasScene"] = true
            batch.setData(["sceneData": try experience.encoded()],
                          forDocument: ref.collection("experience").document("scene"))
        }
        batch.setData(fields, forDocument: ref)
        try await batch.commit()
    }

    enum PostInputError: LocalizedError {
        case invalidText
        var errorDescription: String? { "Use a title of 1–100 characters and a caption of at most 2,000 characters." }
    }

    /// Resizes to feed size and walks JPEG quality down until the bytes fit
    /// comfortably inside Firestore's 1 MB document limit.
    private static func compressedImageData(from image: UIImage, maxDimension: CGFloat = 640) throws -> Data {
        let largestSide = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / max(largestSide, 1))
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        for quality in [0.7, 0.5, 0.35, 0.2] {
            if let data = resized.jpegData(compressionQuality: quality), data.count < 150_000 {
                return data
            }
        }
        throw CreatePostError.imageEncoding
    }

}
