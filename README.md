# Tsudoi (macOS)

Open-source projection app for overlaying live audience comments on
presentation slides. Pair with [`tsudoi-web`](../tsudoi-web) for the
participant and organizer surfaces.

- Native SwiftUI; opens a transparent, click-through, always-on-top window
  above PowerPoint / Keynote.
- Reads comments and reactions from Firestore in real time.
- Read-only: moderation happens in the web admin UI.

License: MIT.

## Requirements

- macOS 13+ (Ventura or later)
- Xcode (latest stable)
- A Firebase project with Firestore Auth (Google SSO) enabled — the web repo
  owns the canonical setup

## Setup

1. **Clone and open**

   ```sh
   git clone <this repo>
   cd tsudoi-macos
   open tsudoi-macos.xcodeproj
   ```

2. **Provide your Firebase config**

   Download `GoogleService-Info.plist` from the Firebase console (macOS app
   registration) and drop it into `tsudoi-macos/` in the Xcode project. It
   is gitignored so each contributor can bring their own.

3. **Copy and edit `Info.plist`**

   `Info.plist` carries the `REVERSED_CLIENT_ID` URL scheme, which is
   Firebase-project-specific. The repo ships `Info.plist.example` as a
   template:

   ```sh
   cp tsudoi-macos/Info.plist.example tsudoi-macos/Info.plist
   ```

   Open `tsudoi-macos/Info.plist` and replace
   `REPLACE_WITH_YOUR_REVERSED_CLIENT_ID` with the value from your
   `GoogleService-Info.plist` (the `REVERSED_CLIENT_ID` key).

4. **Confirm capabilities**

   In the Xcode target's **Signing & Capabilities**:

   - *App Sandbox* → *Network* → **Outgoing Connections (Client)** ✓
   - **Keychain Sharing** capability added (empty group is fine)

   Without these, sign-in will fail with a keychain error or a network
   error.

5. **Run**

   Build and run (`Cmd + R`). The app opens a setup window for Google
   sign-in and event code entry, then transitions to a transparent overlay
   window on the chosen display.

## Usage

1. Sign in with Google.
2. Enter the event code from your `tsudoi-web` admin.
3. The app becomes a transparent overlay on the selected display.
4. From the menu bar, switch display or stop projection.

## Architecture

See `CLAUDE.md` for details on the window configuration, Firestore
listener lifecycle, and schema contract with `tsudoi-web`.

## Contributing

- Keep the Swift models in `Models/` aligned with
  `tsudoi-web/docs/firestore-schema.md`.
- No Firestore writes from this app — it is read-only by design.
- Use Swift Package Manager, not CocoaPods.
