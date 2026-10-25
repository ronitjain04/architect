//
//  SessionStore.swift
//  ARchitect
//
//  Owns the Firebase auth session and the signed-in user's profile document
//  (users/{uid} in Firestore). The auth-state listener is the single source
//  of truth: sign-in from any path (email/password, Google) flows through it,
//  and Firebase persists the session across launches.
//

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

struct UserProfile {
    var username: String
    var displayName: String
    var bio: String
    var uid: String
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var user: FirebaseAuth.User?
    @Published private(set) var profile: UserProfile?

    /// Post document IDs the user has bookmarked.
    @Published private(set) var savedPostIDs: Set<String> = []
    /// Usernames the user follows.
    @Published private(set) var following: Set<String> = []
    @Published private(set) var blockedUIDs: Set<String> = []

    var isAuthenticated: Bool { user != nil && profile != nil }
    @Published var errorMessage: String?
    @Published private(set) var isLoadingProfile = false
    @Published private(set) var isResolvingSession = true
    private var pendingUsername: String?
    private var pendingActions: Set<String> = []

    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        // Previews run without FirebaseApp.configure(); stay inert there.
        guard FirebaseApp.app() != nil else { return }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isResolvingSession = false
                self.isLoadingProfile = user != nil
                self.errorMessage = nil
                self.user = user
                self.profile = nil
                self.savedPostIDs = []
                self.following = []
                self.blockedUIDs = []
                if let user {
                    await self.loadOrCreateProfile(for: user)
                } else {
                    self.profile = nil
                    self.savedPostIDs = []
                    self.following = []
                    self.blockedUIDs = []
                }
            }
        }
    }

    deinit {
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }

    // MARK: - Email / password

    func signUp(username: String, email: String, password: String) async throws {
        let name = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard name.range(of: "^[a-z0-9_]{3,30}$", options: .regularExpression) != nil else {
            throw ProfileError.invalidUsername
        }
        pendingUsername = name
        do {
            _ = try await Auth.auth().createUser(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        } catch { pendingUsername = nil; throw error }
    }

    enum ProfileError: LocalizedError {
        case invalidUsername, usernameTaken
        var errorDescription: String? {
            switch self {
            case .invalidUsername: return "Use 3–30 lowercase letters, numbers, or underscores for your username."
            case .usernameTaken: return "That username is already taken. Choose a different username."
            }
        }
    }

    func logIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signInWithGoogle() {
        GoogleAuthService.signIn { [weak self] error in
            if let error { self?.errorMessage = error.localizedDescription }
        }
    }

    func signOut() {
        do { try Auth.auth().signOut() }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Saved posts & following

    func isSaved(_ postID: String) -> Bool {
        savedPostIDs.contains(postID)
    }

    func toggleSaved(_ postID: String) {
        guard let uid = user?.uid, pendingActions.insert("save_" + postID).inserted else { return }
        let wasSaved = savedPostIDs.contains(postID)
        Task {
            defer { pendingActions.remove("save_" + postID) }
            do {
                try await Firestore.firestore().collection("users").document(uid).updateData([
                    "savedPosts": wasSaved ? FieldValue.arrayRemove([postID]) : FieldValue.arrayUnion([postID])
                ])
                guard user?.uid == uid else { return }
                if wasSaved { savedPostIDs.remove(postID) } else { savedPostIDs.insert(postID) }
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func isFollowing(_ username: String) -> Bool { following.contains(username) }
    func isBlocked(_ uid: String) -> Bool { blockedUIDs.contains(uid) }

    func block(_ uid: String) async -> Bool {
        guard let ownUid = user?.uid, uid != ownUid, !uid.isEmpty else { return false }
        do {
            try await Firestore.firestore().collection("users").document(ownUid)
                .updateData(["blockedUIDs": FieldValue.arrayUnion([uid])])
            guard user?.uid == ownUid else { return false }
            blockedUIDs.insert(uid)
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func toggleFollow(username: String, uid recipientUid: String?) {
        guard let uid = user?.uid, let recipientUid, recipientUid != uid,
              let actorUsername = profile?.username,
              pendingActions.insert("follow_" + username).inserted else { return }
        let wasFollowing = following.contains(username)
        Task {
            defer { pendingActions.remove("follow_" + username) }
            do {
                try await Firestore.firestore().collection("users").document(uid).updateData([
                    "following": wasFollowing ? FieldValue.arrayRemove([username]) : FieldValue.arrayUnion([username])
                ])
                guard user?.uid == uid else { return }
                if wasFollowing {
                    following.remove(username)
                    NotificationService.deleteFollow(recipientUid: recipientUid, actorUid: uid)
                } else {
                    following.insert(username)
                    NotificationService.writeFollow(recipientUid: recipientUid, actorUid: uid, actorUsername: actorUsername)
                }
            } catch { errorMessage = error.localizedDescription }
        }
    }

    // MARK: - Profile document

    func updateProfile(displayName: String, bio: String) async -> Bool {
        guard let uid = user?.uid, displayName.count <= 100, bio.count <= 500 else {
            errorMessage = "Use a name under 100 characters and a bio under 500 characters."
            return false
        }
        do {
            try await Firestore.firestore().collection("users").document(uid).updateData([
                "displayName": displayName, "bio": bio
            ])
            guard user?.uid == uid else { return false }
            profile?.displayName = displayName
            profile?.bio = bio
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func retryProfile(username: String? = nil) async {
        if let username {
            let name = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard name.range(of: "^[a-z0-9_]{3,30}$", options: .regularExpression) != nil else {
                errorMessage = ProfileError.invalidUsername.localizedDescription
                return
            }
            pendingUsername = name
        }
        if let user { await loadOrCreateProfile(for: user) }
    }

    private func loadOrCreateProfile(for authUser: FirebaseAuth.User) async {
        isLoadingProfile = true
        defer { isLoadingProfile = false }
        let db = Firestore.firestore()
        let ref = db.collection("users").document(authUser.uid)
        do {
            let snapshot = try await ref.getDocument()
            guard user?.uid == authUser.uid else { return }
            if snapshot.exists, let data = snapshot.data() {
                profile = UserProfile(username: data["username"] as? String ?? "user",
                    displayName: data["displayName"] as? String ?? "", bio: data["bio"] as? String ?? "", uid: authUser.uid)
                savedPostIDs = Set(data["savedPosts"] as? [String] ?? [])
                following = Set(data["following"] as? [String] ?? [])
                blockedUIDs = Set(data["blockedUIDs"] as? [String] ?? [])
                pendingUsername = nil
                return
            }
            // Do not create a replacement profile when the server read fails.
            let username = pendingUsername ?? "user_" + authUser.uid.lowercased().prefix(20)
            let claim = db.collection("usernames").document(username)
            let legacy = try await db.collection("users").whereField("username", isEqualTo: username).limit(to: 1).getDocuments()
            guard legacy.documents.isEmpty else { throw ProfileError.usernameTaken }
            let fields: [String: Any] = ["username": username, "displayName": authUser.displayName ?? username,
                "bio": "", "createdAt": FieldValue.serverTimestamp()]
            _ = try await db.runTransaction { transaction, pointer -> Any? in
                do {
                    let reservation = try transaction.getDocument(claim)
                    if reservation.exists && reservation.data()?["uid"] as? String != authUser.uid {
                        throw ProfileError.usernameTaken
                    }
                    if !reservation.exists { transaction.setData(["uid": authUser.uid], forDocument: claim) }
                    transaction.setData(fields, forDocument: ref)
                    return nil
                } catch { pointer?.pointee = error as NSError; return nil }
            }
            guard user?.uid == authUser.uid else { return }
            profile = UserProfile(username: username, displayName: authUser.displayName ?? username, bio: "", uid: authUser.uid)
            pendingUsername = nil
        } catch { if user?.uid == authUser.uid { errorMessage = error.localizedDescription } }
    }
}
