# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
this repository.

## Project: Tsudoi (macOS projection app)

Tsudoi is an open-source, self-hostable alternative to CommentScreen — a tool
that overlays live audience comments onto presentation slides, in the style of
Niconico Douga. Built for internal company all-hands meetings where the free
tier of commercial alternatives caps participant counts.

This repository hosts the **macOS projection app**: a native SwiftUI app that
displays a transparent, always-on-top, click-through window over the
presenter's slides (PowerPoint, Keynote, etc.) and animates incoming comments
and reactions across it.

- Related repository: `tsudoi-web` — the web app that participants use to post
  comments, and that organizers use to manage events. Owns the Firebase
  project config and Firestore security rules.
- Design documents: `tsudoi-dev` — Architecture docs and ADRs.
- License: MIT
- Primary documentation language: English (README has a Japanese translation)

## Architecture

### System overview

- **Participants** post comments via the web app (`tsudoi-web`), signing in
  with Google SSO.
- **Firestore** stores comments and reactions under
  `events/{eventId}/comments/*` and `events/{eventId}/reactions/*`.
- **This app** runs on the presenter's Mac. On startup, it authenticates with
  Firebase, opens a transparent full-screen window, and attaches a snapshot
  listener to the active event's subcollections. New comments animate right
  to left; reactions float up.

There is no custom backend. All reads happen directly from Firestore, gated
by rules defined in the `tsudoi-web` repository.

### Tech stack

- Swift + SwiftUI
- Firebase Apple SDK via Swift Package Manager
  - `FirebaseAuth`
  - `FirebaseFirestore`
- macOS 26+ (Tahoe or later) target

### Key directories

```
tsudoi-macos/
├── tsudoi-macos.xcodeproj
└── tsudoi-macos/
    ├── tsudoi_macosApp.swift       # App + AppDelegate (state container)
    ├── ContentView.swift           # Thin wrapper around RootView
    ├── Model/
    │   └── FlowingComment.swift    # Animated comment model + Color(hex:)
    ├── Service/
    │   ├── AuthService.swift       # Google SSO + Firebase Auth wrapper
    │   └── FirestoreService.swift  # Comments listener
    └── View/
        ├── TransparentWindow.swift # WindowAccessor + NSWindow styles
        ├── RootView.swift          # Chooses screen by auth / projection state
        ├── SignInView.swift        # Google sign-in prompt
        ├── CodeEntryView.swift     # Event code entry
        ├── CommentFlowView.swift   # ProjectionView + FlowingCommentView
        └── MenuBarContent.swift    # MenuBarExtra controls
```

Reaction support (`ReactionView.swift`, `Reaction.swift`) is planned for a
later phase — not yet implemented.

## Firestore schema (summary)

The schema is owned by the `tsudoi-web` repository. The canonical document is
at `tsudoi-web/docs/firestore-schema.md`. Do not diverge.

Short version:

```
events/{eventId}
├── comments/{commentId}
└── reactions/{reactionId}
```

- `comments`: `text` (<= 200 chars), `author`, `authorUid`, `authorEmail`,
  `color`, `createdAt`, `hidden` (optional).
- `reactions`: `type` (`heart` / `clap` / `fire`), `authorUid`, `createdAt`.
  Immutable.

Swift models in `Models/` must mirror these exactly. Use `Codable` conformance
with `@DocumentID` for the ID field.

### Query pattern

The app's primary listener:

```
collection: events/{eventId}/comments
where:      hidden != true
order by:   createdAt asc
```

Requires a composite index on `(hidden, createdAt)`, deployed from the
`tsudoi-web` repo's `firestore.indexes.json`.

Reactions are listened separately, ordered by `createdAt`.

## Key design decisions

These were settled after deliberation and should not be revisited without good
reason:

- **Native transparent window, not OBS chroma-key:** the whole point of using
  Swift/macOS for projection (rather than a browser page) is to leverage
  `NSWindow`'s native transparency and click-through. OBS workarounds are not
  needed.
- **Read-only app:** this app never writes to Firestore. It only listens. If
  an organizer needs to hide a comment, they do so from the web admin UI.
- **Separate listeners for comments and reactions:** different animations,
  different lifecycles, different rendering priorities. Do not collapse them
  into one listener.
- **Schema is owned by the web repo:** when in doubt, defer to
  `tsudoi-web/docs/firestore-schema.md`. Do not unilaterally invent new
  fields.

## Window configuration

The transparent window is the core technical challenge. The canonical config:

```swift
window.isOpaque = false
window.backgroundColor = .clear
window.level = .floating                   // always on top
window.ignoresMouseEvents = true           // click-through to the slides below
window.collectionBehavior = [
    .canJoinAllSpaces,
    .fullScreenAuxiliary
]
window.styleMask = [.borderless]
```

This produces a window that sits above the presenter's slides but does not
intercept clicks, so the presenter can continue operating PowerPoint / Keynote
normally.

## Development workflow

### Commit conventions

Conventional Commits with a scope:
- `feat(macos): transparent window basic implementation`
- `feat(comments): bullet-chat animation`
- `fix(firestore): handle empty snapshot`
- `docs: update README`
- `chore: bump Firebase SDK`

### Branching

- `main`: always buildable.
- Feature work on short-lived branches, merged via PR.

### Schema coordination

Before changing a Swift model in `Models/`:

1. Confirm the change is reflected in `tsudoi-web/docs/firestore-schema.md`.
2. If it is not, **stop** — changes must start in the web repo, not here.
3. Once the schema is updated upstream, update the Swift model and note the
   upstream PR in this PR's description.

### Environment setup

- Install Xcode (latest stable).
- Open `tsudoi-macos.xcodeproj`.
- Add `GoogleService-Info.plist` from the Firebase console into the
  `tsudoi-macos/` source folder (it is gitignored — each user supplies their
  own).
- Copy `tsudoi-macos/Info.plist.example` to `tsudoi-macos/Info.plist`, then
  replace `REPLACE_WITH_YOUR_REVERSED_CLIENT_ID` with the `REVERSED_CLIENT_ID`
  from your `GoogleService-Info.plist`. Without this, Google Sign-In cannot
  redirect back into the app. `Info.plist` is gitignored so the
  Firebase-specific URL scheme does not land in git history.
- In **Signing & Capabilities**, confirm:
  - *App Sandbox* → *Network* → **Outgoing Connections (Client)** is enabled
    (Firebase needs to reach `firebaseapp.com` / `googleapis.com`).
  - *Keychain Sharing* capability is added (Firebase Auth stores tokens in
    Keychain; sandboxed apps need the capability even with an empty group).
- Swift Package dependencies resolve on first build.
- Build and run (`Cmd + R`).

## What Claude should do / avoid

### Do

- Use `Codable` + `@DocumentID` for all Firestore models. Do not hand-roll
  dictionary parsing.
- Use `addSnapshotListener` for real-time updates; never poll.
- Handle listener lifecycle carefully (detach on view disappear, reattach on
  event change). Zombie listeners are a common bug source.
- Keep animations performant. Target 60fps with up to `maxConcurrent` (default
  50) comments on screen simultaneously.
- Follow the commit conventions above.
- Read `Models/` first to understand the schema before modifying Firestore
  interaction code.

### Avoid

- **Do not** commit `GoogleService-Info.plist` — it is tied to a specific
  Firebase project and each user should supply their own.
- **Do not** add write paths to Firestore from this app. It is read-only by
  design. If moderation-like features are needed, they belong in the web repo.
- **Do not** add browser-based rendering (e.g. WKWebView that loads an HTML
  page). The whole reason this app exists in native Swift is to leverage
  `NSWindow` transparency, which browsers can't match.
- **Do not** diverge the Swift models from the canonical schema. If you need
  a field that doesn't exist, update the schema upstream first.
- **Do not** use CocoaPods. Stick with Swift Package Manager.
- **Do not** assume iOS APIs work on macOS. Firebase's macOS support is
  official beta — test anything unusual before assuming.
- **Do not** invent new reaction types (e.g. `star`, `thumbsup`) without
  updating `firestore.rules` in the `tsudoi-web` repo. Unknown types will be
  rejected at write time and dropped here.

## Useful context

- The tool is for internal events (50–200 participants, monthly cadence, ~1h).
  Performance targets are modest but firm: comments must appear on screen
  within ~500ms of posting, and the window must stay pinned above the
  presenter's slides across full-screen transitions.
- The presenter is assumed to be running macOS with PowerPoint or Keynote in
  windowed or presentation mode. This app runs alongside, above it, with
  click-through enabled so the presenter never interacts with it mid-talk.
- The typical runtime is: open app → sign in once → enter event code → the
  window goes transparent and starts listening. Closing the app or changing
  events is rare mid-session. Keep the UX aligned with that reality — no
  elaborate settings panels on the projection surface itself.
