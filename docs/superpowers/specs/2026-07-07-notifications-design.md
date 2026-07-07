# Notifications / activity feed — design

Date: 2026-07-07
Status: Approved, ready for planning

## Context

The social layer shipped in phase-3-social (profile, saved posts, following,
people search) made likes, comments, and follows real, but nothing tells a
user when someone else acts on their content or account. This closes that
loop with an in-app activity feed.

**Out of scope** (deliberately deferred):
- Push notifications (APNs/FCM) — no push infra exists yet; this is in-app
  only, surfaced via a bell icon and badge.
- Mentions/replies in comments — requires comment threading and @mention
  parsing, neither of which exists. Left as a future project once comments
  support replies.

## Data model

A `notifications` subcollection under each recipient's user document:
`users/{recipientUid}/notifications/{notifID}`.

```
type:          "like" | "comment" | "follow"
actorUsername: String
postID:        String?   // set for like/comment, nil for follow
read:          Bool
createdAt:     Timestamp
```

This colocates with the existing per-user data pattern (`savedPosts`,
`following` already live as fields on `users/{uid}`), rather than
introducing a new top-level collection.

### Dedup strategy

`likedBy` and `following` are current-state arrays today, not event logs —
notifications for like/follow track the same current truth rather than
accumulating spam from toggling:

- **Like** → deterministic ID `like_{postID}_{actorUsername}`, `setData` on
  like, **deleted on unlike**.
- **Follow** → deterministic ID `follow_{actorUsername}`, `setData` on
  follow, **deleted on unfollow**.
- **Comment** → auto-generated ID, one doc per comment (comments are already
  an append-only log — no delete path; a stray notification for a deleted
  comment is harmless and comments have no delete-by-others path anyway).

Re-liking after unliking simply resurfaces the same doc (unread again)
instead of creating duplicates.

## Security rules

```
match /users/{userId}/notifications/{notifID} {
  allow read: if isSignedIn() && request.auth.uid == userId;

  allow create: if isSignedIn()
    && request.resource.data.actorUsername is string
    && request.resource.data.type in ['like', 'comment', 'follow'];

  allow update: if isSignedIn() && request.auth.uid == userId
    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['read']);

  allow delete: if isSignedIn();
}
```

Self-notification (e.g. liking your own post) is filtered client-side by
skipping the write when `actorUsername == recipientUsername`, not enforced
server-side — matching the app's existing trust model for non-adversarial
cases like `commentCount`.

## Write paths

Plain follow-up Firestore calls right after the existing state-changing
call — not batched in a `WriteBatch`. Matches the rest of the app's
pattern (e.g. `toggleLike`'s optimistic UI flip isn't atomic with its
Firestore write today); worst case a notification silently doesn't fire,
never data corruption.

1. **`Post.toggleLike()`** (`Post.swift:102`) — needs the post author's
   `uid`. `Post` currently writes `authorUid` on create but never reads it
   back; add `let authorUid: String` to `Post`, populated in
   `init(docID:data:)`. On like: `setData` the deterministic doc. On
   unlike: `delete` it.

2. **`CommentViewModel.addComment()`** (`CommentViewModel.swift:67`) — the
   view model only has `postDocID`, not the author. Thread `authorUid`
   in from `Post.addComment(text:publisher:)`, which already holds `self`.
   Writes an auto-ID notification doc.

3. **`SessionStore.toggleFollow(username:)`** (`SessionStore.swift:107`) —
   needs the target's `uid`, which `SessionStore` doesn't have. Extend
   `SocialService.PublicUser` to carry `uid` (the query already fetches the
   doc, just needs to keep `documentID`), and change the signature to
   `toggleFollow(username: String, uid: String)`, threaded from
   `UserProfileView` (which already calls `fetchUser` for the Follow
   button).

All three sites guard with `actorUsername != recipientUsername` before
writing.

## UI

- **Bell icon**: added to `feedHeader` (`ARMediaView.swift:81`), trailing
  side. Taps push a new `ActivityView` onto the feed's `NavigationStack`.
- **Badge**: unread count via a `.count` aggregation query on
  `users/{uid}/notifications` where `read == false` — same pattern as
  `SocialService.followerCount`. Fetched on appear / pull-to-refresh, not
  live-listened (consistent with the app's one-shot-query style outside
  the feed itself).
- **`ActivityView`** (new: `View/Activity/ActivityView.swift`): live
  `addSnapshotListener` on `users/{uid}/notifications`, ordered by
  `createdAt desc`, `limit(50)` (no pagination exists anywhere in the app
  yet, so a simple cap matches current conventions). Each row: actor
  username, action text ("liked your post" / "commented: \"...\"" /
  "started following you"), relative time (reusing `Post.time_ago()`'s
  logic), and a post thumbnail for like/comment rows.
- **Per-item read state**: tapping a row marks that doc `read: true` and
  navigates — like/comment rows to the post (needs a new one-shot
  `SocialService.fetchPost(id:)`, since posts are currently only reachable
  as array elements from `FeedStore`, not fetched standalone by ID), follow
  rows to `UserProfileView(username:)`.

## Error handling

Matches the app's existing liberal `try?` style — this is non-critical,
user-visible-but-not-blocking functionality:

- Notification writes use `try?` fire-and-forget, same as `toggleLike`'s
  Firestore update.
- Badge count defaults to `0` on aggregate-query failure rather than
  showing an error.
- `ActivityView`'s empty/failed state reuses the `emptyFeed` pattern (icon
  + message): "No activity yet."

## Testing

No automated test suite exists in this repo (`ARchitectTests` /
`ARchitectUITests` are empty stubs). Verification is manual on simulator,
same process as phase-3-social:

- Like a post from a second account → author sees badge + row.
- Comment from a second account → author sees badge + row.
- Follow / unfollow → notification appears / disappears.
- Tap-through navigation to post and to profile.
- Unlike removes the earlier like notification.
