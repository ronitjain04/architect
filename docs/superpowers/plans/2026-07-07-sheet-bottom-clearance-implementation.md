# Half-Sheet Bottom Clearance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the app's four partial-height sheets the same 28pt bottom clearance the floating nav bar uses, instead of each sheet's current ad-hoc spacing.

**Architecture:** Four independent, single-file edits — no shared code, no new abstractions. Each sheet's bottom-most content gets a `.padding(.bottom, 28)` (or, for the two fixed-height sheets, an equivalent detent-height bump), matching the literal `28` already used in `BottomNavigationBar.swift`.

**Tech Stack:** Swift, SwiftUI.

**Source spec:** `docs/superpowers/specs/2026-07-07-sheet-bottom-clearance-design.md`

## Global Constraints

- **No build/test tooling in this environment.** No working Xcode (`xcodebuild -list` fails to resolve schemes) and no simulator access. Implementers and reviewers verify every task by careful reading — matching Swift syntax, exact existing code, and the design spec's stated intent — not by compiling or running. The human will build and visually check on-device after this lands (the spec's Testing section lists what to check).
- **The literal value is `28`**, matching `BottomNavigationBar.swift`'s own `.padding(.bottom, 28)`. Do not introduce a named constant — the spec explicitly rejected that (only 4 structurally-different call sites, and the codebase already prefers inline literals for this exact class of problem, e.g. `ARMediaView`'s `.padding(.bottom, 90) // clear the floating tab bar`).
- **For the two fixed-height sheets (`MenuSheet`, `EditProfileSheet`), this only guarantees the bottom margin grows by exactly 28pt more than it was before** — not a verified-exact 28pt total gap, since the prior slack is unknown without running the app. Say so in each of those two tasks' self-review notes; don't claim more precision than the diff actually provides.
- **Do not touch `AuthenticationView`** (`MainView.swift`) — it's a full-size `.sheet` with no `.presentationDetents`, explicitly out of scope per the spec.

---

### Task 1: MenuSheet bottom clearance

**Files:**
- Modify: `ARchitect/View/ARMedia/MenuSheet.swift`

**Interfaces:** None — self-contained UI change, nothing else depends on this file's internals.

- [ ] **Step 1: Bump both presentation-detent heights by 28**

In `MenuSheet.swift`, the `body`'s modifier chain currently ends:

```swift
        .padding(.top, AppSpacing.md)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(isOwnPost ? 230 : 170)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appBackground)
```

Change the `.presentationDetents` line only:

```swift
        .padding(.top, AppSpacing.md)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(isOwnPost ? 258 : 198)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appBackground)
```

(`230 + 28 = 258`, `170 + 28 = 198`.) The `VStack`'s content and its
`.frame(maxHeight: .infinity, alignment: .top)` are unchanged, so the rows
stay pinned to the top of the sheet and the blank margin below them grows
by exactly 28pt.

- [ ] **Step 2: Self-review**

Confirm only the two numbers inside `.presentationDetents([.height(...)])`
changed (`230`→`258`, `170`→`198`), and that no other line in the file was
touched — in particular, `.frame(maxHeight: .infinity, alignment: .top)`
must remain exactly as it was, since that's what keeps content top-anchored
and makes the height bump translate into added *bottom* space rather than
somewhere else. Note in your report that this verifiably adds 28pt more
bottom margin than existed before, not a confirmed-exact 28pt total gap
(per this plan's Global Constraints).

- [ ] **Step 3: Commit**

```bash
git add ARchitect/View/ARMedia/MenuSheet.swift
git commit -m "Give MenuSheet the nav bar's 28pt bottom clearance"
```

---

### Task 2: CommentSectionView input-bar bottom clearance

**Files:**
- Modify: `ARchitect/View/ARMedia/CommentSectionView.swift`

**Interfaces:** None — self-contained UI change.

- [ ] **Step 1: Split the input bar's vertical padding into explicit top/bottom**

In `CommentSectionView.swift`, inside `CommentSheetContent`'s `body`, the
input bar (an `HStack` containing the avatar, text field, and send button)
currently ends:

```swift
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm + 2)
        }
    }
```

Change the `.padding(.vertical, ...)` line to two explicit lines:

```swift
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm + 2)
            .padding(.bottom, 28)
        }
    }
```

This is the last modifier chain in `CommentSheetContent`'s outer `VStack`
(the input bar is the last element), so this directly sets the sheet's
final bottom clearance — no fixed-height/slack ambiguity here, unlike
Task 1.

- [ ] **Step 2: Self-review**

Confirm the top padding value is unchanged (`AppSpacing.sm + 2`, i.e. the
same 10pt gap above the input bar as before — only the *bottom* padding
changed), and that the input bar is still horizontally padded by
`AppSpacing.md` exactly as before. Confirm no other file in this task was
touched.

- [ ] **Step 3: Commit**

```bash
git add ARchitect/View/ARMedia/CommentSectionView.swift
git commit -m "Give CommentSectionView's input bar the nav bar's 28pt bottom clearance"
```

---

### Task 3: FurnitureGallerySheet bottom clearance

**Files:**
- Modify: `ARchitect/View/ARCapture/ARCaptureView.swift`

**Interfaces:** None — self-contained UI change.

- [ ] **Step 1: Add bottom padding to the scrollable list's VStack**

In `ARCaptureView.swift`, inside `FurnitureGallerySheet`'s `body`, the
`ScrollView` currently wraps its `VStack` like this:

```swift
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(models, id: \.self) { model in
                        Button {
                            onSelect(model)
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                ZStack {
                                    Circle().fill(Color.appSurfaceAlt)
                                    Image(systemName: "chair.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.appPrimary)
                                }
                                .frame(width: 44, height: 44)

                                Text(model.capitalized)
                                    .font(AppFont.inter(15, .regular))
                                    .foregroundColor(.appText)

                                Spacer()

                                Image(systemName: "plus.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(.appAccent)
                            }
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }

                        Divider()
                            .background(Color.appDivider)
                            .padding(.leading, 76)
                    }
                }
            }
```

Add `.padding(.bottom, 28)` to the inner `VStack`, right after the
`ForEach`'s closing brace:

```swift
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(models, id: \.self) { model in
                        Button {
                            onSelect(model)
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                ZStack {
                                    Circle().fill(Color.appSurfaceAlt)
                                    Image(systemName: "chair.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.appPrimary)
                                }
                                .frame(width: 44, height: 44)

                                Text(model.capitalized)
                                    .font(AppFont.inter(15, .regular))
                                    .foregroundColor(.appText)

                                Spacer()

                                Image(systemName: "plus.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(.appAccent)
                            }
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }

                        Divider()
                            .background(Color.appDivider)
                            .padding(.leading, 76)
                    }
                }
                .padding(.bottom, 28)
            }
```

This mirrors `ARMediaView.swift`'s existing `.padding(.bottom, 90) // clear
the floating tab bar` on its own feed `LazyVStack` — same technique, same
codebase precedent, applied to this scrollable list.

- [ ] **Step 2: Self-review**

Confirm `.padding(.bottom, 28)` was added to the `VStack` *inside* the
`ScrollView` (not to the `ScrollView` itself, and not to the outer
`VStack(spacing: 0)` that also contains the "Add furniture" title and
divider) — it must apply only to the scrollable list content, so it adds
clearance after the last row rather than padding the whole sheet. Confirm
`.presentationDetents([.medium])` and everything else in the file is
unchanged.

- [ ] **Step 3: Commit**

```bash
git add ARchitect/View/ARCapture/ARCaptureView.swift
git commit -m "Give FurnitureGallerySheet's list the nav bar's 28pt bottom clearance"
```

---

### Task 4: EditProfileSheet bottom-anchor and clearance

**Files:**
- Modify: `ARchitect/View/Profile/ProfileView.swift`

**Interfaces:** None — self-contained UI change.

- [ ] **Step 1: Replace the trailing Spacer with explicit bottom padding, and pin content to the top**

In `ProfileView.swift`, `EditProfileSheet`'s `body` currently reads:

```swift
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Text("Edit profile")
                .font(AppFont.inter(15, .semibold))
                .foregroundColor(.appText)
                .padding(.top, AppSpacing.md)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Name")
                    .font(AppFont.inter(13, .semibold))
                    .foregroundColor(.appTextSecondary)
                AuthField(placeholder: "Name", text: $displayName)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Bio")
                    .font(AppFont.inter(13, .semibold))
                    .foregroundColor(.appTextSecondary)
                TextField("Bio", text: $bio, axis: .vertical)
                    .lineLimit(2...4)
                    .font(AppFont.body)
                    .foregroundColor(.appText)
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                            .fill(Color.appSurfaceAlt)
                    )
            }

            Button("Done") {
                Task {
                    await session.updateProfile(displayName: displayName, bio: bio)
                    dismiss()
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            Spacer()
        }
        .padding(.horizontal, AppSpacing.lg)
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appBackground)
    }
```

Replace it with (the trailing `Spacer()` is removed, `.padding(.bottom, 28)`
is added after the `Button`, and `.frame(maxHeight: .infinity, alignment:
.top)` is added to the modifier chain, mirroring `MenuSheet`'s own
top-anchoring technique from Task 1):

```swift
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Text("Edit profile")
                .font(AppFont.inter(15, .semibold))
                .foregroundColor(.appText)
                .padding(.top, AppSpacing.md)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Name")
                    .font(AppFont.inter(13, .semibold))
                    .foregroundColor(.appTextSecondary)
                AuthField(placeholder: "Name", text: $displayName)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Bio")
                    .font(AppFont.inter(13, .semibold))
                    .foregroundColor(.appTextSecondary)
                TextField("Bio", text: $bio, axis: .vertical)
                    .lineLimit(2...4)
                    .font(AppFont.body)
                    .foregroundColor(.appText)
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                            .fill(Color.appSurfaceAlt)
                    )
            }

            Button("Done") {
                Task {
                    await session.updateProfile(displayName: displayName, bio: bio)
                    dismiss()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.bottom, 28)
        }
        .padding(.horizontal, AppSpacing.lg)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appBackground)
    }
```

**Net visible effect (expected and approved during brainstorming):** the
Done button moves down, close to the sheet's bottom edge with a 28pt gap,
instead of floating mid-sheet above a large blank Spacer-driven gap.

- [ ] **Step 2: Self-review**

Confirm the trailing `Spacer()` inside the `VStack` is gone (there should
be no bare `Spacer()` call left in `EditProfileSheet.body`). Confirm
`.padding(.bottom, 28)` is attached to the `Button("Done")` (after its
`.buttonStyle(PrimaryButtonStyle())`), not to the outer `VStack`. Confirm
`.frame(maxHeight: .infinity, alignment: .top)` was added to the outer
modifier chain, positioned before `.presentationDetents` (matching where
`MenuSheet` places its own equivalent frame modifier, for consistency).
Confirm `.presentationDetents([.height(380)])` itself is unchanged — this
task does not change the sheet's total height, only how content is
anchored within it. Note in your report, per this plan's Global
Constraints, that this is a real layout change (Done button visibly moves)
that was already explicitly approved, not a regression to flag.

- [ ] **Step 3: Commit**

```bash
git add ARchitect/View/Profile/ProfileView.swift
git commit -m "Anchor EditProfileSheet content to the top with the nav bar's 28pt bottom clearance"
```
