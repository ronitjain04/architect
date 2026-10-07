# ARchitect

An iPhone app for scanning a room, arranging bundled furniture in AR, and sharing a measured 3D reconstruction with other signed-in users. Built with SwiftUI, RoomPlan, ARKit, SceneKit, Firebase Authentication, and Cloud Firestore.

## Beta setup

- Open `ARchitect.xcodeproj` in Xcode. The app target is iPhone-only, requires iOS 18 or later, and uses bundle ID `com.ronitJain.Architect`. The checked-in team `K995CAS64M` currently resolves to a free personal team; select an active Apple Developer Program team before archiving for TestFlight.
- Sign into the matching Apple Developer team in Xcode Settings → Accounts and connect an unlocked LiDAR-equipped iPhone (the intended physical test device is an iPhone 16 Pro). RoomPlan capture cannot be validated in Simulator.
- The checked-in `GoogleService-Info.plist` points to Firebase project `architect-31445`. Before inviting testers, deploy the tested Firestore rules with `firebase deploy --only firestore:rules --project architect-31445`. Review any production rule changes against older installed builds first.
- Sign in with Apple is included alongside Google and email login. Enable the Sign in with Apple capability for this app ID in the Apple Developer account and the Apple provider in Firebase Authentication before testing it on-device. Xcode's signing profile must include the capability.
- Build and run on the phone. Sign in, grant camera access, scan a room, place furniture, publish, and open the post on a second account/device. Try the shared `architect://room/<post-id>` link on a signed-in install, rotate the 3D view, and place the reconstructed room in AR.
- Archive the Release configuration in Xcode and upload through Organizer to App Store Connect → TestFlight. External testers require Apple's first-build beta review and TestFlight test information. The archive needs a valid team signing profile; an unsigned simulator build cannot be uploaded.

The scan is a RoomPlan reconstruction of walls, openings, and recognized furniture categories, plus the app's bundled furniture transforms. It is not a photorealistic scan or an exported camera mesh.

## Cost and data limits

No Cloud Storage bucket, paid Functions, or uploaded furniture assets are used. Each post stores a compressed preview (at most 150 KB) and a bounded scene document (at most 300 KB) in Firestore. At the maximum sizes, 10 testers publishing 20 rooms each would use under 90 MB of post preview/scene data before document/index overhead. Firebase's current Firestore no-cost quota is 1 GiB stored, 50,000 reads/day, 20,000 writes/day, 20,000 deletes/day, and 10 GiB/month outbound. Check the Firebase console's Firestore Usage page during the beta; the project's billing is currently disabled. [Firestore free quota](https://firebase.google.com/docs/firestore/quotas). TestFlight itself requires an Apple Developer Program membership, currently listed by Apple at $99/year in the US. [Apple membership](https://developer.apple.com/programs/enroll/).

## Checks

The scene model's standalone checks live in `Tests/SceneCore`. Firestore rules tests live in `Tests/Firebase`; from that directory, run `npm ci` and `npm test` with Node 22 and Java available. Run the `ARchitect` Xcode test scheme on an iPhone simulator for app tests. A physical LiDAR test remains required before inviting external testers.

## Beta moderation and deletion

Users can report a post, block its author, and request deletion from the profile menu. These requests require a human operator during this small beta because the project intentionally avoids paid server infrastructure. Check the queue at least daily and respond promptly. Do not invite testers unless someone will operate this workflow.

The operator script is `Tests/Firebase/beta-ops.mjs`. It uses Firebase Admin SDK and application-default credentials for an account with access to `architect-31445`. Set `GOOGLE_APPLICATION_CREDENTIALS` to a protected service-account JSON file outside this repository, or use another supported ADC method. Never commit credentials. From `Tests/Firebase`, run `node beta-ops.mjs queue` to inspect reports and pending deletions. `remove-post POST_ID`, `resolve-report REPORT_ID`, and `delete-account UID` print a dry run; append `--apply` only after checking the IDs. Review and remove violating posts, then resolve the report. Deletion removes the account's posts and nested room data, authored comments, likes, notifications, profile, username reservation, related reports, Firebase Auth user, and the request record. Recheck the queue after any interrupted operation.

This operator path is for roughly 10 testers. It scans the small user/post collection to clean references; it is not designed for a large public launch. A public release needs a staffed moderation process, published support contact, and a more scalable deletion job. TestFlight reviewers also need working credentials and clear instructions for the LiDAR feature.
