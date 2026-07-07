# Notifications / Activity Feed Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an in-app activity feed (bell icon + badge + screen) that notifies a user when someone likes their post, comments on their post, or follows them.

**Architecture:** A new `users/{uid}/notifications` Firestore subcollection, written by the actor's client at the same three call sites that already mutate likes/comments/follows (`Post.toggleLike`, `CommentViewModel.addComment`, `SessionStore.toggleFollow`). A new `NotificationService` (one-shot write/delete/count helpers, mirrors the existing `SocialService`) and `ActivityStore` (live listener, mirrors `FeedStore`/`CommentViewModel`) back a new `ActivityView` screen reached via a bell icon added to the feed header.

**Tech Stack:** Swift, SwiftUI, Firebase Auth, Firestore (no Cloud Functions — all writes are client-side, consistent with the rest of the app).

**Source spec:** `docs/superpowers/specs/2026-07-07-notifications-design.md`

## Global Constraints

- **No build/test tooling in this environment.** This sandbox has Xcode Command Line Tools but not full Xcode (`xcodebuild -list` fails to resolve schemes) and no Firebase CLI. Implementers and reviewers verify every task by careful reading — matching existing compiling code's patterns, exact signatures, and Swift syntax — not by running a build. The human will build, run on simulator, and manually verify per the spec's Testing section after tasks land; do not claim "tests pass" or attempt to invoke `xcodebuild`.
- **Firestore rules are file-only.** Task 1 edits `firestore.rules` in the repo. No task runs `firebase deploy` — that pushes to shared/production infrastructure and the human deploys it manually when ready.
- **Self-notification check uses uid equality**, not username equality (`actorUid != recipientUid`), since uid is already on hand at every write site and is the more reliable identity check. This achieves the same outcome the spec describes ("skip when actor == recipient").
- **Error handling matches the existing codebase style**: Firestore writes are fire-and-forget (no `try`/`await` on the notification write itself unless the surrounding function is already `async`), consistent with `Post.toggleLike`'s existing `updateData` call and `CommentViewModel.addComment`'s existing `addDocument` call.
- **Reuse existing design tokens** — `AppSpacing`, `AppFont.inter`/`AppFont.fraunces`, `Color.appText`, `Color.appTextSecondary`, `Color.appBackground`, `Color.appDivider`, `Color.appLike`, `Color.appPrimary`, `Color.appSurfaceAlt`, and the `Avatar(monogram:size:)` view — all defined in `ARchitect/View/Shared/Theme.swift`. Do not introduce new colors or fonts.
- **Navigation pattern**: this codebase uses `.navigationDestination(isPresented:)` paired with a separately-held `@State` value (see `ARMediaView.swift:195`), not `.navigationDestination(item:)`. Follow the same pattern for `ActivityView`'s post/profile navigation — `Post` is a class and does not conform to `Hashable`, so `.navigationDestination(item:)` would not compile for it.

---

### Task 1: Firestore rules for the notifications subcollection

**Files:**
- Modify: `firestore.rules`

**Interfaces:**
- Produces: security rules only — no Swift interface. Later tasks' writes/reads rely on this shape existing (`users/{userId}/notifications/{notifId}` with fields `type`, `actorUsername`, `postID`, `read`, `createdAt`).

- [ ] **Step 1: Add the notifications match block inside the existing `users` rule**

In `firestore.rules`, the `match /users/{userId} { ... }` block currently reads:

```
    match /users/{userId} {
      allow read: if isSignedIn();
      allow create, update, delete: if isSignedIn() && request.auth.uid == userId;
    }
```

Replace it with:

```
    match /users/{userId} {
      allow read: if isSignedIn();
      allow create, update, delete: if isSignedIn() && request.auth.uid == userId;

      match /notifications/{notifId} {
        allow read: if isSignedIn() && request.auth.uid == userId;

        allow create: if isSignedIn()
          && request.resource.data.actorUsername is string
          && request.resource.data.type in ['like', 'comment', 'follow'];

        allow update: if isSignedIn() && request.auth.uid == userId
          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['read']);

        allow delete: if isSignedIn();
      }
    }
```

- [ ] **Step 2: Self-review**

Confirm braces balance (the file should still have one top-level `service cloud.firestore { match /databases/{database}/documents { ... } }` wrapping everything), and that the `posts` match block below is untouched.

- [ ] **Step 3: Commit**

```bash
git add firestore.rules
git commit -m "Add Firestore rules for the notifications subcollection"
```

---

### Task 2: Add `authorUid` to the `Post` model

**Files:**
- Modify: `ARchitect/Model/Post.swift`

**Interfaces:**
- Produces: `Post.authorUid: String` — the Firestore `authorUid` field read back onto the model (the post document already writes this field on create at `FeedStore.swift:105`, but `Post` never read it back). Empty string for posts built via the local/preview initializers.

- [ ] **Step 1: Add the stored property**

In `Post.swift`, add `let authorUid: String` next to the other `let` properties (after `let description: String`, i.e. right before `let timeAgo: Date` — either position works, keep it grouped with the other Firestore-sourced `let`s):

```swift
    let description: String
    let authorUid: String
    let timeAgo: Date
```

- [ ] **Step 2: Populate it in the Firestore initializer**

In `init(docID: String, data: [String: Any])`, add the assignment alongside the other field reads (after `self.description = ...`):

```swift
        self.description = data["description"] as? String ?? ""
        self.authorUid = data["authorUid"] as? String ?? ""
        self.timeAgo = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
```

- [ ] **Step 3: Populate it in both local/preview initializers**

In `init(username:userImage:title:imageName:description:likes:user_liked:commentsModel:)`, add `self.authorUid = ""` after `self.description = description`:

```swift
        self.description = description
        self.authorUid = ""
        self.timeAgo = Date()
```

In `init(imageName: String)`, add `self.authorUid = ""` after `self.description = "..."`:

```swift
        self.description = "Lengthy description about the furniture and the positioning of different elements that were used."
        self.authorUid = ""
        self.timeAgo = Date()
```

- [ ] **Step 4: Self-review**

Confirm all three initializers now assign `authorUid` (grep the file for `authorUid` — should appear once as a `let` declaration and three times as an assignment). Confirm no other code references a `Post.authorUid` yet (this task only adds the property; nothing consumes it until Task 4/5).

- [ ] **Step 5: Commit**

```bash
git add ARchitect/Model/Post.swift
git commit -m "Read authorUid back onto the Post model"
```

---

### Task 3: NotificationService — data model and Firestore helpers

**Files:**
- Create: `ARchitect/Model/NotificationService.swift`

**Interfaces:**
- Produces:
  - `struct AppNotification: Identifiable` — `id: String`, `type: NotificationType`, `actorUsername: String`, `postID: String?`, `read: Bool`, `createdAt: Date`; nested `enum NotificationType: String { case like, comment, follow }`.
  - `NotificationService.writeLike(recipientUid: String, actorUid: String, actorUsername: String, postID: String)`
  - `NotificationService.deleteLike(recipientUid: String, actorUsername: String, postID: String)`
  - `NotificationService.writeComment(recipientUid: String, actorUid: String, actorUsername: String, postID: String)`
  - `NotificationService.writeFollow(recipientUid: String, actorUid: String, actorUsername: String)`
  - `NotificationService.deleteFollow(recipientUid: String, actorUsername: String)`
  - `NotificationService.unreadCount(uid: String) async -> Int`
  - `NotificationService.markRead(uid: String, notificationID: String)`

- [ ] **Step 1: Create the file**

Create `ARchitect/Model/NotificationService.swift` with this exact content:

```swift
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
```

- [ ] **Step 2: Self-review**

Confirm every method that writes guards on `actorUid != recipientUid` (self-notification) except the two read methods (`unreadCount`, `markRead`), which don't need it. Confirm `AppNotification` conforms to `Identifiable` (required for `ForEach` in Task 9). Confirm import list matches other `Model/` files that only touch Firestore, not Auth (this file never calls `Auth.auth()` — callers pass `actorUid` in).

- [ ] **Step 3: Commit**

```bash
git add ARchitect/Model/NotificationService.swift
git commit -m "Add NotificationService: writes, deletes, and unread count for the activity feed"
```

---

### Task 4: Wire like notifications into `Post.toggleLike`

**Files:**
- Modify: `ARchitect/Model/Post.swift`
- Modify: `ARchitect/View/ARMedia/PostView.swift`
- Modify: `ARchitect/View/ARMedia/ARMediaView.swift`

**Interfaces:**
- Consumes: `Post.authorUid` (Task 2), `NotificationService.writeLike` / `.deleteLike` (Task 3).
- Produces: `Post.toggleLike(actorUsername: String)` — replaces the old no-argument `toggleLike()`. No later task depends on this further; all three call sites are updated in this same task.

- [ ] **Step 1: Change `Post.toggleLike()` to take the actor's username and notify**

In `Post.swift`, replace:

```swift
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
```

with:

```swift
    func toggleLike(actorUsername: String) {
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

        guard !actorUsername.isEmpty else { return }
        if user_liked {
            NotificationService.writeLike(
                recipientUid: authorUid,
                actorUid: uid,
                actorUsername: actorUsername,
                postID: docID
            )
        } else {
            NotificationService.deleteLike(
                recipientUid: authorUid,
                actorUsername: actorUsername,
                postID: docID
            )
        }
    }
```

- [ ] **Step 2: Update the call site in `PostView.swift`**

At `PostView.swift:101`, replace:

```swift
                                post.toggleLike()
```

with:

```swift
                                post.toggleLike(actorUsername: session.profile?.username ?? "")
```

(`session` is already available in this file as `@EnvironmentObject var session: SessionStore` at `PostView.swift:11`.)

- [ ] **Step 3: Update the two call sites in `ARMediaView.swift`**

At `ARMediaView.swift:203` (inside the action-bar like button), replace:

```swift
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    post.toggleLike()
                } label: {
```

with:

```swift
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    post.toggleLike(actorUsername: session.profile?.username ?? "")
                } label: {
```

At `ARMediaView.swift:280` (inside `doubleTapLike()`), replace:

```swift
        if !post.user_liked {
            post.toggleLike()
        }
```

with:

```swift
        if !post.user_liked {
            post.toggleLike(actorUsername: session.profile?.username ?? "")
        }
```

(`session` is already available in `FeedPostCard` as `@EnvironmentObject var session: SessionStore` at `ARMediaView.swift:137`, and `doubleTapLike()` is a method on that same struct, so `session` is in scope there too.)

- [ ] **Step 4: Self-review**

Grep the repo for `toggleLike(` and confirm there are exactly four occurrences: the one declaration in `Post.swift` and three call sites, all passing `actorUsername:`. Confirm no call site was missed (a leftover `post.toggleLike()` with no arguments would not compile).

- [ ] **Step 5: Commit**

```bash
git add ARchitect/Model/Post.swift ARchitect/View/ARMedia/PostView.swift ARchitect/View/ARMedia/ARMediaView.swift
git commit -m "Notify post authors when their post is liked"
```

---

### Task 5: Wire comment notifications into `CommentViewModel`

**Files:**
- Modify: `ARchitect/Model/CommentViewModel.swift`
- Modify: `ARchitect/Model/Post.swift`

**Interfaces:**
- Consumes: `Post.authorUid` (Task 2), `NotificationService.writeComment` (Task 3).
- Produces: `CommentViewModel(postDocID: String?, postAuthorUid: String = "")` — the two-argument initializer used by `Post`; the existing no-argument `init()` (for local/preview comment lists) is unchanged.

- [ ] **Step 1: Add `postAuthorUid` to `CommentViewModel`**

In `CommentViewModel.swift`, replace:

```swift
    private let postDocID: String?
    private var listener: ListenerRegistration?
```

with:

```swift
    private let postDocID: String?
    private let postAuthorUid: String
    private var listener: ListenerRegistration?
```

Replace the two initializers:

```swift
    /// Local, in-memory comments (previews and sample posts).
    init() {
        postDocID = nil
    }

    /// Comments backed by posts/{postDocID}/comments.
    init(postDocID: String?) {
        self.postDocID = postDocID
    }
```

with:

```swift
    /// Local, in-memory comments (previews and sample posts).
    init() {
        postDocID = nil
        postAuthorUid = ""
    }

    /// Comments backed by posts/{postDocID}/comments.
    init(postDocID: String?, postAuthorUid: String = "") {
        self.postDocID = postDocID
        self.postAuthorUid = postAuthorUid
    }
```

- [ ] **Step 2: Notify the post author when a comment is added**

Replace:

```swift
    func addComment(text: String, publisher: String) {
        if let postDocID, FirebaseApp.app() != nil {
            let post = Firestore.firestore().collection("posts").document(postDocID)
            post.collection("comments").addDocument(data: [
                "authorUid": Auth.auth().currentUser?.uid ?? "",
                "text": text,
                "publisher": publisher,
                "timestamp": FieldValue.serverTimestamp(),
            ])
            post.updateData(["commentCount": FieldValue.increment(Int64(1))])
            // The listener delivers the new comment; nothing to append locally.
        } else {
```

with:

```swift
    func addComment(text: String, publisher: String) {
        if let postDocID, FirebaseApp.app() != nil {
            let post = Firestore.firestore().collection("posts").document(postDocID)
            post.collection("comments").addDocument(data: [
                "authorUid": Auth.auth().currentUser?.uid ?? "",
                "text": text,
                "publisher": publisher,
                "timestamp": FieldValue.serverTimestamp(),
            ])
            post.updateData(["commentCount": FieldValue.increment(Int64(1))])
            // The listener delivers the new comment; nothing to append locally.

            if let uid = Auth.auth().currentUser?.uid {
                NotificationService.writeComment(
                    recipientUid: postAuthorUid,
                    actorUid: uid,
                    actorUsername: publisher,
                    postID: postDocID
                )
            }
        } else {
```

- [ ] **Step 3: Pass `authorUid` through from `Post`**

In `Post.swift`, in `init(docID: String, data: [String: Any])`, replace:

```swift
        self.commentsModel = CommentViewModel(postDocID: docID)
```

with:

```swift
        self.commentsModel = CommentViewModel(postDocID: docID, postAuthorUid: self.authorUid)
```

(`self.authorUid` is assigned earlier in this same initializer per Task 2, so it's available here.)

- [ ] **Step 4: Self-review**

Confirm `CommentViewModel()` (no-arg, used by both local/preview `Post` initializers and any SwiftUI previews) still compiles unchanged. Confirm the only two-argument call site is the one just added in `Post.swift`. Confirm the notification write sits *inside* the `if let postDocID, FirebaseApp.app() != nil` branch, not the `else` branch (local/preview comments never touch Firestore).

- [ ] **Step 5: Commit**

```bash
git add ARchitect/Model/CommentViewModel.swift ARchitect/Model/Post.swift
git commit -m "Notify post authors when their post is commented on"
```

---

### Task 6: Wire follow notifications

**Files:**
- Modify: `ARchitect/Model/SocialService.swift`
- Modify: `ARchitect/Model/SessionStore.swift`
- Modify: `ARchitect/View/Profile/UserProfileView.swift`

**Interfaces:**
- Consumes: `NotificationService.writeFollow` / `.deleteFollow` (Task 3).
- Produces: `SocialService.PublicUser.uid: String`; `SessionStore.toggleFollow(username: String, uid: String?)` (replaces the old single-argument `toggleFollow(_:)`); `FollowButton(username: String, uid: String?, onToggle:)` (replaces the old two-argument initializer).

- [ ] **Step 1: Add `uid` to `PublicUser` and capture it in `fetchUser`**

In `SocialService.swift`, replace:

```swift
struct PublicUser {
    let profile: UserProfile
    let followingCount: Int
}
```

with:

```swift
struct PublicUser {
    let profile: UserProfile
    let followingCount: Int
    let uid: String
}
```

Replace:

```swift
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
```

with:

```swift
    static func fetchUser(username: String) async -> PublicUser? {
        let snapshot = try? await Firestore.firestore().collection("users")
            .whereField("username", isEqualTo: username)
            .limit(to: 1)
            .getDocuments()
        guard let document = snapshot?.documents.first else { return nil }
        let data = document.data()
        return PublicUser(
            profile: UserProfile(
                username: data["username"] as? String ?? username,
                displayName: data["displayName"] as? String ?? "",
                bio: data["bio"] as? String ?? ""
            ),
            followingCount: (data["following"] as? [String])?.count ?? 0,
            uid: document.documentID
        )
    }
```

- [ ] **Step 2: Change `SessionStore.toggleFollow` to accept the target's uid and notify**

In `SessionStore.swift`, replace:

```swift
    func toggleFollow(_ username: String) {
        guard username != profile?.username else { return }
        if following.contains(username) {
            following.remove(username)
        } else {
            following.insert(username)
        }
        persistOwnDoc(["following": Array(following)])
    }
```

with:

```swift
    func toggleFollow(username: String, uid: String?) {
        guard username != profile?.username else { return }
        let wasFollowing = following.contains(username)
        if wasFollowing {
            following.remove(username)
        } else {
            following.insert(username)
        }
        persistOwnDoc(["following": Array(following)])

        guard let recipientUid = uid, let actorUid = user?.uid, let actorUsername = profile?.username else { return }
        if wasFollowing {
            NotificationService.deleteFollow(recipientUid: recipientUid, actorUsername: actorUsername)
        } else {
            NotificationService.writeFollow(recipientUid: recipientUid, actorUid: actorUid, actorUsername: actorUsername)
        }
    }
```

- [ ] **Step 3: Thread the uid through `FollowButton` and its call site**

In `UserProfileView.swift`, replace the `FollowButton` struct's properties and body:

```swift
struct FollowButton: View {
    @EnvironmentObject var session: SessionStore
    let username: String
    /// Called with +1 / -1 so the presenting view can adjust its follower
    /// count optimistically.
    var onToggle: (Int) -> Void = { _ in }

    var body: some View {
        let following = session.isFollowing(username)
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            session.toggleFollow(username)
            onToggle(following ? -1 : +1)
        } label: {
```

with:

```swift
struct FollowButton: View {
    @EnvironmentObject var session: SessionStore
    let username: String
    /// The target's Firestore uid, when they have an account (nil for
    /// seeded demo authors, who can still be followed but never notified).
    let uid: String?
    /// Called with +1 / -1 so the presenting view can adjust its follower
    /// count optimistically.
    var onToggle: (Int) -> Void = { _ in }

    var body: some View {
        let following = session.isFollowing(username)
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            session.toggleFollow(username: username, uid: uid)
            onToggle(following ? -1 : +1)
        } label: {
```

(the rest of the `body` — the `Text(...)` label and its modifiers — is unchanged)

Update the call site in `UserProfileView.header`, replacing:

```swift
            if !isSelf {
                FollowButton(username: username) { delta in
                    followerCount = max(0, followerCount + delta)
                }
            }
```

with:

```swift
            if !isSelf {
                FollowButton(username: username, uid: publicUser?.uid) { delta in
                    followerCount = max(0, followerCount + delta)
                }
            }
```

- [ ] **Step 4: Self-review**

Grep for `toggleFollow(` and confirm both the declaration (`SessionStore.swift`) and its one call site (inside `FollowButton.body`) use the new `username:uid:` label pair. Grep for `FollowButton(` and confirm the one call site passes `uid:`. Confirm `#Preview` blocks that construct `FollowButton` directly (if any) also pass `uid:` — check the bottom of `UserProfileView.swift` for a preview that might reference `FollowButton` directly (the existing preview only constructs `UserProfileView`, not `FollowButton`, so no change should be needed there, but verify).

- [ ] **Step 5: Commit**

```bash
git add ARchitect/Model/SocialService.swift ARchitect/Model/SessionStore.swift ARchitect/View/Profile/UserProfileView.swift
git commit -m "Notify users when someone follows them"
```

---

### Task 7: `SocialService.fetchPost(id:)`

**Files:**
- Modify: `ARchitect/Model/SocialService.swift`

**Interfaces:**
- Produces: `SocialService.fetchPost(id: String) async -> Post?` — a one-shot lookup by document ID, used by `ActivityView` (Task 9) to navigate from a like/comment notification to the post behind it (posts are otherwise only reachable as array elements from `FeedStore`, never fetched standalone).

- [ ] **Step 1: Add the method**

In `SocialService.swift`, add this method to the `SocialService` enum, after `fetchPosts(ids:)` and before `followerCount(of:)`:

```swift
    /// A single post by document ID — used by the activity feed to jump to
    /// the post behind a like/comment notification.
    static func fetchPost(id: String) async -> Post? {
        guard let snapshot = try? await Firestore.firestore().collection("posts").document(id).getDocument(),
              snapshot.exists, let data = snapshot.data() else { return nil }
        return Post(docID: snapshot.documentID, data: data)
    }
```

- [ ] **Step 2: Self-review**

Confirm this follows the same `try?` / optional-return style as every other method in this file (e.g. `fetchUser`), and that `Post(docID:data:)` is the same initializer `FeedStore` and `SocialService.fetchPosts` already use.

- [ ] **Step 3: Commit**

```bash
git add ARchitect/Model/SocialService.swift
git commit -m "Add SocialService.fetchPost(id:) for activity-feed navigation"
```

---

### Task 8: `ActivityStore` — live notifications listener

**Files:**
- Create: `ARchitect/Model/ActivityStore.swift`

**Interfaces:**
- Consumes: `AppNotification`, `NotificationService.markRead` (Task 3).
- Produces: `ActivityStore: ObservableObject` with `@Published private(set) var notifications: [AppNotification]`, `@Published private(set) var isLoading: Bool`, `start(uid: String)`, `stop()`, `markRead(_ notification: AppNotification, uid: String)`.

- [ ] **Step 1: Create the file**

Create `ARchitect/Model/ActivityStore.swift` with this exact content (mirrors `FeedStore`'s listener lifecycle):

```swift
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
```

- [ ] **Step 2: Self-review**

Compare against `FeedStore.swift` line-by-line for the listener lifecycle shape (`guard listener == nil`, `[weak self]`, `Task { @MainActor [weak self] in ... }`, `defer { isLoading = false }`) — it should match exactly. Confirm `compactMap` (not `map`) is used since an unrecognized `type` string should be dropped, not crash or produce a bogus row.

- [ ] **Step 3: Commit**

```bash
git add ARchitect/Model/ActivityStore.swift
git commit -m "Add ActivityStore: live listener for the activity feed"
```

---

### Task 9: `ActivityView` screen

**Files:**
- Create: `ARchitect/View/Activity/ActivityView.swift`

**Interfaces:**
- Consumes: `ActivityStore` (Task 8), `SocialService.fetchPost(id:)` (Task 7), existing `UserProfileView(username: String)`, existing `PostView(post: Post)`.
- Produces: `ActivityView: View` — no initializer parameters; reads `session: SessionStore` from the environment (same pattern as `ARMediaView`, `UserProfileView`).

- [ ] **Step 1: Create the file**

Create `ARchitect/View/Activity/ActivityView.swift` with this exact content:

```swift
//
//  ActivityView.swift
//  ARchitect
//
//  The activity feed reached from the bell icon on the main feed: likes,
//  comments, and new followers on the signed-in user's content. Tapping a
//  row marks it read and navigates to the post or profile behind it.
//

import SwiftUI

struct ActivityView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var store = ActivityStore()

    @State private var selectedPost: Post?
    @State private var showPost = false
    @State private var selectedUsername: String?
    @State private var showProfile = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if store.isLoading {
                ProgressView()
                    .tint(.appPrimary)
            } else if store.notifications.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.notifications) { notification in
                            Button {
                                handleTap(notification)
                            } label: {
                                row(for: notification)
                            }
                            .buttonStyle(.plain)

                            Divider().background(Color.appDivider)
                        }
                    }
                }
            }
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let uid = session.user?.uid {
                store.start(uid: uid)
            }
        }
        .navigationDestination(isPresented: $showPost) {
            if let selectedPost {
                PostView(post: selectedPost)
            }
        }
        .navigationDestination(isPresented: $showProfile) {
            if let selectedUsername {
                UserProfileView(username: selectedUsername)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "bell")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.appTextSecondary)
            Text("No activity yet")
                .font(AppFont.inter(17, .semibold))
                .foregroundColor(.appText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func row(for notification: AppNotification) -> some View {
        HStack(spacing: AppSpacing.md) {
            Avatar(monogram: notification.actorUsername, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                (Text(notification.actorUsername).font(AppFont.inter(13, .semibold))
                 + Text(" \(actionText(for: notification.type))").font(AppFont.inter(13, .regular)))
                    .foregroundColor(.appText)
                Text(relativeTime(notification.createdAt))
                    .font(AppFont.inter(11, .regular))
                    .foregroundColor(.appTextSecondary)
            }

            Spacer()

            if !notification.read {
                Circle()
                    .fill(Color.appLike)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func actionText(for type: AppNotification.NotificationType) -> String {
        switch type {
        case .like: return "liked your post"
        case .comment: return "commented on your post"
        case .follow: return "started following you"
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(Int(diff / 60))m" }
        if diff < 86400 { return "\(Int(diff / 3600))h" }
        return "\(Int(diff / 86400))d"
    }

    private func handleTap(_ notification: AppNotification) {
        if let uid = session.user?.uid {
            store.markRead(notification, uid: uid)
        }
        switch notification.type {
        case .follow:
            selectedUsername = notification.actorUsername
            showProfile = true
        case .like, .comment:
            guard let postID = notification.postID else { return }
            Task {
                if let post = await SocialService.fetchPost(id: postID) {
                    selectedPost = post
                    showPost = true
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ActivityView()
            .environmentObject(SessionStore())
    }
}
```

- [ ] **Step 2: Self-review**

Confirm `.contentShape(Rectangle())` is present on the row (needed so the whole row area is tappable, not just the text/avatar) — this matches the tap-target intent already established elsewhere in the app (see `690ba88 Polish UI: flush tab bar, grid tap targets` in git log). Confirm the two `.navigationDestination(isPresented:)` blocks match the existing pattern at `ARMediaView.swift:195` exactly (guard-unwrap inside the destination closure, not force-unwrap). Confirm `Avatar`, `AppSpacing`, `AppFont` usages match their exact signatures from `Theme.swift` (checked in Task interfaces already used identically elsewhere, e.g. `UserProfileView.swift`).

- [ ] **Step 3: Commit**

```bash
git add ARchitect/View/Activity/ActivityView.swift
git commit -m "Add ActivityView: the activity feed screen"
```

---

### Task 10: Bell icon and unread badge in the feed header

**Files:**
- Modify: `ARchitect/View/ARMedia/ARMediaView.swift`

**Interfaces:**
- Consumes: `ActivityView` (Task 9), `NotificationService.unreadCount(uid:)` (Task 3).
- Produces: nothing further downstream — this is the last task.

- [ ] **Step 1: Add unread-count state and a refresh helper**

In `ARMediaView.swift`, in the `ARMediaView` struct, replace:

```swift
struct ARMediaView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var feed = FeedStore()

    private var posts: [Post] { feed.posts }
```

with:

```swift
struct ARMediaView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var feed = FeedStore()
    @State private var unreadCount = 0

    private var posts: [Post] { feed.posts }
```

- [ ] **Step 2: Refresh the count on appear and on pull-to-refresh**

Replace:

```swift
                .refreshable {
                    // The snapshot listener keeps the feed live; this is just
                    // the familiar gesture.
                    try? await Task.sleep(nanoseconds: 400_000_000)
                }
            }
        }
        // This view supplies its own header, so hide the native nav bar to
        // avoid a duplicate empty bar above it.
        .toolbar(.hidden, for: .navigationBar)
        // Security rules require a signed-in user, and a listener attached
        // pre-auth stays denied — so (re)attach whenever auth flips on.
        .task(id: session.isAuthenticated) {
            if session.isAuthenticated {
                feed.restart()
            } else {
                feed.stopListening()
            }
        }
    }
```

with:

```swift
                .refreshable {
                    // The snapshot listener keeps the feed live; this is just
                    // the familiar gesture.
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    await refreshUnreadCount()
                }
            }
        }
        // This view supplies its own header, so hide the native nav bar to
        // avoid a duplicate empty bar above it.
        .toolbar(.hidden, for: .navigationBar)
        // Security rules require a signed-in user, and a listener attached
        // pre-auth stays denied — so (re)attach whenever auth flips on.
        .task(id: session.isAuthenticated) {
            if session.isAuthenticated {
                feed.restart()
            } else {
                feed.stopListening()
            }
        }
        // Also refresh whenever the feed tab's root reappears — e.g.
        // returning from the activity screen after reading notifications.
        .onAppear {
            Task { await refreshUnreadCount() }
        }
    }

    private func refreshUnreadCount() async {
        guard let uid = session.user?.uid else {
            unreadCount = 0
            return
        }
        unreadCount = await NotificationService.unreadCount(uid: uid)
    }
```

- [ ] **Step 3: Add the bell icon to `feedHeader`**

Replace:

```swift
    private var feedHeader: some View {
        HStack {
            Text("ARchitect")
                .font(AppFont.fraunces(26, .semibold))
                .foregroundColor(.appText)

            Spacer()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 10)
    }
```

with:

```swift
    private var feedHeader: some View {
        HStack {
            Text("ARchitect")
                .font(AppFont.fraunces(26, .semibold))
                .foregroundColor(.appText)

            Spacer()

            NavigationLink(destination: ActivityView()) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.appText)

                    if unreadCount > 0 {
                        Circle()
                            .fill(Color.appLike)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 10)
    }
```

- [ ] **Step 4: Self-review**

Confirm `NavigationLink(destination: ActivityView())` is placed inside `ARMediaView`'s own body, which is the root content of `feedPath`'s `NavigationStack` (declared at `RootTabView.swift:36-40`) — so this push targets the feed tab's own stack, matching how `FeedPostCard`'s `NavigationLink(destination: UserProfileView(...))` already pushes onto the same stack. Confirm `refreshUnreadCount()` is a private method on `ARMediaView` (not `FeedPostCard` — it's a different struct) and is called from both `.onAppear` and inside `.refreshable`. Confirm the badge dot reuses `Color.appLike` (same red-ish accent already used for the unread dot in `ActivityView`'s rows from Task 9, and for the like heart elsewhere).

- [ ] **Step 5: Commit**

```bash
git add ARchitect/View/ARMedia/ARMediaView.swift
git commit -m "Add bell icon and unread badge to the feed header"
```
