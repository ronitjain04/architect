# Half-sheet bottom clearance — design

Date: 2026-07-07
Status: Approved, ready for planning

## Context

The floating bottom nav bar (`BottomNavigationBar.swift`) doesn't float above a
gap — its background sits flush with the true screen bottom (the root view
`.ignoresSafeArea(edges: .bottom)`), and its tap targets are pulled up 28pt
from that edge via `.padding(.bottom, 28)`, "to clear the home indicator,
Instagram-style."

The app's four partial-height sheets (`.presentationDetents`-based — the ones
that visually read as "half sheets") each landed with their own ad-hoc
bottom spacing, none of it referencing that 28pt value:

- `MenuSheet` (post options) — content top-anchored to a fixed detent height,
  whatever blank margin exists at the bottom is incidental.
- `CommentSectionView`'s input bar — 10pt bottom padding
  (`AppSpacing.sm + 2`).
- `EditProfileSheet` — ends with a `Spacer()` after the Done button, so Done
  sits mid-sheet with a large, arbitrary gap below it.
- `FurnitureGallerySheet` — a scrollable list with no bottom inset at all.

This gives every sheet in the app a different, uncoordinated bottom margin.
Goal: give each one the same 28pt clearance the nav bar itself uses, so the
app's bottom-edge spacing reads as one consistent convention.

**Out of scope:** `AuthenticationView`, presented via `.sheet` with no
`.presentationDetents` (a full-size sheet, not a half sheet) — excluded per
explicit scope decision during brainstorming.

## Approach

Inline literal `.padding(.bottom, 28)` (or equivalent) at each sheet's
bottom-most content, matching this codebase's existing convention —
`ARMediaView`'s feed already hardcodes `.padding(.bottom, 90) // clear the
floating tab bar` for an analogous problem, with no shared constant. A new
shared `AppSpacing` constant or reusable modifier was considered and
rejected: only 4 call sites, each structurally different (fixed-height
top-anchored, system-detent with a pinned input bar, fixed-height with a
trailing Spacer, scrollable list), so a shared abstraction would need
per-case overrides anyway — premature for this scope.

**Verification caveat:** no working Xcode/simulator is available in the
environment this was planned in (same constraint hit during the preceding
notifications-feed work). For the two fixed-height sheets (`MenuSheet`,
`EditProfileSheet`), the changes below are verified to add *exactly 28pt
more* bottom clearance than existed before, not verified as an exact 28pt
total gap (unknown prior slack). The two other sheets (`CommentSectionView`,
`FurnitureGallerySheet`) are deterministic — their bottom padding directly
sets the final gap. A quick on-device glance after this lands is worth
doing, especially for `MenuSheet` and `EditProfileSheet`.

## Per-sheet changes

### MenuSheet.swift

Content is top-anchored via `.frame(maxHeight: .infinity, alignment: .top)`
inside a fixed-height sheet. Bump both `.presentationDetents` heights by 28:

- `.height(170)` → `.height(198)` (2-row case)
- `.height(230)` → `.height(258)` (3-row, own-post case)

Content itself is unchanged; since it stays top-anchored, the blank margin
at the sheet's bottom grows by exactly 28pt.

### CommentSectionView.swift (`CommentSheetContent`'s input bar)

The input bar is the last element in the VStack, sized to `.medium`/`.large`
system detents — no fixed height to tune, so this is fully deterministic.
Split the current `.padding(.vertical, AppSpacing.sm + 2)` into explicit
top/bottom:

```swift
.padding(.horizontal, AppSpacing.md)
.padding(.top, AppSpacing.sm + 2)
.padding(.bottom, 28)
```

### ARchitect/View/ARCapture/ARCaptureView.swift (`FurnitureGallerySheet`)

A scrollable list inside a `.medium` detent. Add `.padding(.bottom, 28)` to
the `VStack` inside the `ScrollView` (after the `ForEach` of model rows),
directly mirroring `ARMediaView`'s own `.padding(.bottom, 90)` fix for the
same class of problem — content should have 28pt of clearance below the
last row before the sheet's bottom edge.

### ProfileView.swift (`EditProfileSheet`)

This is a real layout change, not just added padding. Today the VStack ends
with `Button("Done") { ... }.buttonStyle(PrimaryButtonStyle())` followed by
`Spacer()`, so Done sits mid-sheet with a large, arbitrary gap below it
(whatever the fixed 380pt height leaves over).

Change:
- Remove the trailing `Spacer()`.
- Add `.padding(.bottom, 28)` after the Done button.
- Add `.frame(maxHeight: .infinity, alignment: .top)` to the VStack (mirroring
  `MenuSheet`'s own technique), so content reliably top-anchors within the
  fixed 380pt sheet rather than relying on undefined default alignment for
  under-sized content in a `.presentationDetents`-sized sheet.

**Net visible effect:** the Done button moves down, close to the sheet's
bottom edge (28pt gap), instead of floating mid-sheet above a large blank
Spacer-driven gap. This was explicitly called out and approved during
brainstorming.

## Testing

No automated test suite or working build tooling exists in the environment
this was planned in (same constraint as the preceding notifications-feed
work). Verification is by careful code review, not compilation. On-device
checks worth doing after this lands, in order of how much this design could
be wrong without visual confirmation:
- `MenuSheet`: open post options on both an own post (3 rows) and someone
  else's post (2 rows) — confirm the bottom margin visually matches the nav
  bar's own clearance.
- `EditProfileSheet`: open "Edit profile" — confirm the Done button now
  sits near the bottom with a small, consistent gap, not floating mid-sheet.
- `CommentSectionView` and `FurnitureGallerySheet`: quick visual spot-check,
  lower risk since these are deterministic.
