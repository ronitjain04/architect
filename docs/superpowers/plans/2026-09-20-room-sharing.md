# Scanned Room Sharing Implementation Plan

**Goal:** iPhone TestFlight beta that captures a measured room and shares it with placed furniture.
**Architecture:** RoomPlan shares an ARSession with the furniture editor. A versioned, bounded scene document stores measured surfaces and furniture transforms in Firestore. A local renderer rebuilds geometry; bundled furniture avoids paid asset storage.
**Spec:** ../specs/2026-09-20-testflight-beta-scope.md
**Constraints:** iPhone only; existing Firebase project; no billing changes; preserve existing posts; current UI; physical validation on iPhone 16 Pro.

- [ ] Scene contract: Foundation-only Codable model, validated transforms, limits, future-version rejection, serialization tests runnable using Swift CLI.
- [ ] Capture: RoomPlan scan with camera/support/error states; shared ARSession preserves coordinate alignment; preview before publishing.
- [ ] Placement: stable model IDs, correct anchor-relative placement, preserve duplicate instances and final transforms, remove selected item, correct catalog previews.
- [ ] Persistence: enforce a total post payload budget; include scene data; decode legacy posts as image-only; no placeholder scenes.
- [ ] Viewer: measured room geometry plus bundled furniture; orbit preview and AR placement; explicit missing-asset/error states.
- [ ] Backend: actor/owner authorization, failure feedback, bounded reads, deterministic notification ownership, emulator rules tests.
- [ ] Release: iPhone build settings, meaningful tests, physical test checklist, signed archive, TestFlight processing.

## Validation

Run the pure scene contract against hand-authored fixtures: duplicate chair instances at different positions, a 90-degree rotation, invalid matrices/scales, unsupported version, and over-budget payload. Compile all changed Swift files with Xcode, then run simulator tests. Exercise room scan, placement after scan, cancel/retry, scene reload from another account, permission denial, and offline publication on device. Test database rules using two actors and an unrelated third account. Archive and verify App Store Connect processing before marking the beta available.

## Current external blocker

Xcode license/first-launch setup prevents xcodebuild. Owner has been asked to complete setup. Pure Foundation tests can run with the installed Command Line Tools. No passing iOS build or device result may be claimed until measured.
