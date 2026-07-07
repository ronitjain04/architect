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
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var user: FirebaseAuth.User?
    @Published private(set) var profile: UserProfile?

    var isAuthenticated: Bool { user != nil }

    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        // Previews run without FirebaseApp.configure(); stay inert there.
        guard FirebaseApp.app() != nil else { return }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.user = user
                if let user {
                    await self.loadOrCreateProfile(for: user)
                } else {
                    self.profile = nil
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
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let profile = UserProfile(username: username, displayName: username, bio: "")
        try await Firestore.firestore().collection("users").document(result.user.uid).setData([
            "username": profile.username,
            "displayName": profile.displayName,
            "bio": profile.bio,
            "createdAt": FieldValue.serverTimestamp(),
        ])
        self.profile = profile
    }

    func logIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signInWithGoogle() {
        GoogleAuthService.signIn {
            // The auth-state listener picks up the new session.
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
    }

    // MARK: - Profile document

    func updateProfile(displayName: String, bio: String) async {
        guard let uid = user?.uid else { return }
        profile?.displayName = displayName
        profile?.bio = bio
        try? await Firestore.firestore().collection("users").document(uid).setData([
            "displayName": displayName,
            "bio": bio,
        ], merge: true)
    }

    private func loadOrCreateProfile(for user: FirebaseAuth.User) async {
        let ref = Firestore.firestore().collection("users").document(user.uid)

        if let snapshot = try? await ref.getDocument(), snapshot.exists, let data = snapshot.data() {
            profile = UserProfile(
                username: data["username"] as? String ?? "user",
                displayName: data["displayName"] as? String ?? "",
                bio: data["bio"] as? String ?? ""
            )
            return
        }

        // First sign-in without a profile (e.g. Google) — derive a starter one.
        let emailPrefix = user.email?.split(separator: "@").first.map(String.init)
        let username = emailPrefix ?? "user\(String(user.uid.prefix(6)))"
        let starter = UserProfile(
            username: username,
            displayName: user.displayName ?? username,
            bio: ""
        )
        try? await ref.setData([
            "username": starter.username,
            "displayName": starter.displayName,
            "bio": starter.bio,
            "createdAt": FieldValue.serverTimestamp(),
        ])
        profile = starter
    }
}
