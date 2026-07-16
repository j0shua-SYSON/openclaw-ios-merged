# SmartTube (YouTube) mode integration

Upstream: `github.com/milika/SmartTubeIOS` (native Swift/SwiftUI YouTube client, on the App
Store as "Smart Tube BDP"). This is the **open-source** answer to a YouTube mode — the closed
YouTube binary is a dead end (BotGuard/po_token + App Attest + 203 MB obfuscated; see
`Modes/YouTube/.work`). SmartTube already solves po_token by running BotGuard's JS solver in
JavaScriptCore, and authenticates via the YouTube-TV device-code grant (no app-identity
binding), so it works where the binary can't.

## Why this is the EASIEST embed yet (unlike UTM)

SmartTubeIOS is a **Swift Package library**, not an app target:
- Products: `SmartTubeIOSCore` (Foundation-only models/services) + `SmartTubeIOS` (SwiftUI UI).
- Root view is `public struct RootView` — parameterless, reads everything from the SwiftUI
  environment.
- No app→framework conversion (unlike UTM). OpenClaw just depends on the package and presents
  `RootView` via a launcher.
- **No Bundle.main problem**: SPM resources (the `yt.solver.*.min.js` po_token solvers,
  `Localizable.xcstrings`) load via `Bundle.module`, which resolves to the package's own
  resource bundle inside the host app — not `Bundle.main`. This is the trap UTM hit; SPM
  avoids it structurally.

## The one complication: FirebaseCrashlytics

`Sources/SmartTubeIOS` depends on `firebase-ios-sdk` (`FirebaseCrashlytics`) purely for crash
reporting/logging. Problems if kept: heavy transitive graph, needs a `GoogleService-Info.plist`
tied to the app's bundle id, and OpenClaw already pulls `GoogleUtilities` via Delta's Google
Sign-In → duplicate-symbol risk. Crashlytics is non-functional (reporting only), so the fork
**strips it**:
- Patch `Package.swift`: drop the `firebase-ios-sdk` dependency + the `FirebaseCrashlytics`
  product from the `SmartTubeIOS` target.
- Replace `Services/CrashlyticsLogger.swift` with a Firebase-free `os.Logger` stub that keeps
  the SAME public API, so the ~27 call sites compile unchanged. (`FirebaseApp.configure()` lives
  only in the app wrapper `AppEntry`, which we don't include.)

## Fork layout (Modes/SmartTube/fork)

- `SmartTubeLauncher.swift` — added INTO the package (Sources/SmartTubeIOS); `@objc` class with
  `makeRootViewController()` that reproduces AppEntry's iOS setup: build InnerTubeAPI (poToken via
  `BotGuardClient()`), AuthService, BrowseViewModel, SettingsStore, PlayerStateStore,
  TOSPlayerStateStore, PlayerRouter, VideoDownloadService; inject all into `RootView()`'s
  environment + the essential auth-token `.onChange` wiring; wrap in `UIHostingController`.
- `CrashlyticsLogger.swift` — the Firebase-free stub (overwrites upstream's).
- `apply_fork.sh` — clone → patch Package.swift (drop Firebase) → drop in launcher + stub.

## Wiring

- `project.yml`: local package dep `packages: SmartTubeIOS: {path: <clone>}`, OpenClaw target
  `- package: SmartTubeIOS product: SmartTubeIOS`.
- Bridging header: forward-declare `SmartTubeLauncher` (resolve at link time; avoids importing
  the module into OpenClaw's Swift).
- `Sources/ModeSwitcher.swift`: `SmartTubeModeView` + `case "smarttube"` + registry entry.
- `ios-build.yml`: clone milika/SmartTubeIOS @ pinned SHA → apply fork → xcodegen resolves the
  local package → build. No prebuilt framework to embed (SPM builds from source into OpenClaw);
  the po_token JS + localizations ride along as the package resource bundle.

## Notes / risks

- License: SmartTubeIOS is [see LICENSE — recon]; consistent with the project's other
  copyleft modes (Delta/etc.). User's call.
- Guest/anonymous browse works; sign-in is the YouTube-TV device-code flow (user activates at
  yt.be/activate) — no redirect URL / SDK identity needed, so it survives embedding.
- App-group `group.com.void.smarttube` is used only by the app wrapper (share ext / widget),
  not the library RootView — bypassed.
- Swift 6 language mode (matches OpenClaw's SWIFT_VERSION 6.0 / strict concurrency).
