# ARchitect iPhone TestFlight beta scope

## Confirmed direction

- Deliver an iPhone-only TestFlight beta.
- Share the creator's scanned room and furniture, beyond screenshots alone.
- Use the configured Firebase project, architect-31445.
- Avoid paid storage where practical; disclose costs before enabling billing.
- Keep and polish the current interface.
- The owner can test on a physical iPhone.

## Approved AR design

Recommended first beta: capture the creator's room using Apple RoomPlan and
reconstruct its measured geometry alongside added catalog furniture. Store a versioned scene containing stable
catalog model IDs and each instance's position, rotation, and scale relative
to one scene origin. Preserve repeated instances of the same model. Include
measured walls, floors, doors, windows, and openings plus simplified detected
furniture. Support an interactive 3D viewer and AR placement of the room model.

RoomPlan creates a parametric model, not a photographic reconstruction of
textures and belongings. The owner approved this fidelity on September 20. Photorealistic textured capture requires a different pipeline and cost
estimate. Capture requires a compatible LiDAR device; inspect runtime support.
The owner will test on an iPhone 16 Pro. View-only support should not
require LiDAR. Never substitute the current sample apartment for a user's scan.

## Recommended implementation sequence

1. Unify catalog metadata and model resources. Each furniture page must open
   the selected item. Validate availability and physical scale of bundled assets.
2. Implement scene capture, serialization, persistence, and replay after the
   sharing decision. Existing screenshot-only posts remain viewable and do not
   claim to contain a reconstructable scene.
3. Harden authentication/profile lifecycle, UID-based ownership and social
   actions, database rules, error recovery, and post deletion cleanup. Preserve
   existing project data and inspect deployed configuration before migration.
4. Polish current screens: loading, empty, error, camera permission, AR tracking,
   unsupported-device states, and accessible controls. Bound feed queries and
   image transfer; remove automatic production database demo seeding.
5. Verify model/data tests, Firebase emulator authorization tests, simulator
   navigation, and physical-device AR flows. Prepare release configuration,
   signing, beta instructions, and a TestFlight archive/upload when available.

## Cost approach

Prefer bundled catalog models and compact measured room/scene documents. Keep
compressed preview images within explicit limits; reconstruct room geometry on
the viewer's device instead of uploading USDZ files for the proposed parametric
beta. Measure payload size and use a bounded schema; do not assume every scan fits
Firestore's document limit. Avoid fetching every preview again on each feed change. Exempt large image
and scene payload fields from indexing as appropriate.

Firestore's documented free allocation is 1 GiB stored, 50,000 document reads/day,
20,000 writes/day, 20,000 deletes/day, and 10 GiB outbound/month. These are shared
project quotas, not guaranteed available capacity. Current plan, region, usage,
and deployed rules have not been verified from the Firebase account.

Cloud Storage requires Blaze billing even when usage falls within a free tier.
Legacy appspot buckets list 5 GB storage free, then $0.026/GB-month; downloads
have separate quotas and charges. New buckets use region-dependent Google Cloud
Storage pricing. Do not activate billing as part of implementation.

Sources checked September 20, 2026:
- https://firebase.google.com/docs/firestore/quotas
- https://firebase.google.com/pricing
- https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024
- https://developer.apple.com/augmented-reality/roomplan/
- https://developer.apple.com/videos/play/wwdc2022/10127/

## Completion evidence

- A user can sign up/sign in, browse furniture, place multiple items, publish,
  and open the resulting experience from another account.
- Replay preserves model identity, multiplicity, relative position, rotation,
  and scale; scene data survives app restart.
- Social actions enforce author/actor ownership and surface failed writes.
- Legacy posts render without invented scene content.
- Unit and rules tests pass; simulator flows and physical-device AR checks are
  documented with actual results.
- Release build targets iPhone, archives successfully, and is processed in
  App Store Connect before TestFlight availability is claimed.

## Owner setup and release inputs

- Complete Xcode license/first-launch setup; xcodebuild currently exits 69.
- Confirm iPhone model/iOS version for the physical testing matrix.
- Provide signed-in access to the intended Apple Developer team and Firebase
  console/CLI when backend deployment and TestFlight distribution are needed.
  Do not paste credentials into chat.
- Establish whether testers are internal team members or external invitees.

This is a scope record and proposed AR design, not a completed implementation
or a claim that the current app builds.
