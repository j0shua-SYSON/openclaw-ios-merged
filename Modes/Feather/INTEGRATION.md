# Feather mode — integration notes

Source: `khcrysalis/Feather` cloned at `F:\JOSHUA_1st_2021\projects\Feather` (read-only; CI clones its
own copy). On-device IPA signing + install (signs with the user's `.p12` + `.mobileprovision` via
Zsign; installs via a local Vapor HTTPS server / AFC pairing). **License: GPL-3.0** (app layer) — the
in-repo SPM packages are MIT. Copyleft applies to a distributed OpenClaw that statically links it.

## Shape (from survey)

- **Swift 5.0** app target (not 6 — CLAUDE.md's "Swift 6" is repo vibe; `SWIFT_VERSION=5.0` in pbxproj),
  **SwiftUI**-first with light UIKit interop, iOS 16+, single app target `Feather`, single scheme.
- 98 Swift + **2 ObjC** files (`Utilities/MachO/MachOUtils.m`, `Utilities/iconPoc.m`) reached via
  `Feather/Supporting Files/Feather-Bridging-Header.h` (imports `MachOUtils.h`, `iconPoc.h`).
- Builds standalone: `xcodebuild -project Feather.xcodeproj -scheme Feather` (packages are
  `XCLocalSwiftPackageReference`, resolve without the workspace). `make` just wraps that + ad-hoc sign
  + copies `deps/`. **`make deps`** (backloop.dev TLS cert → `deps/server.{crt,pem}`) is a **runtime**
  asset for the HTTPS install path, **not** a build requirement.

## Entry & root

- `Feather/FeatherApp.swift`: `@main struct FeatherApp: App` + `@UIApplicationDelegateAdaptor(AppDelegate)`.
  Launch steps (AppDelegate): `_createPipeline()` (Nuke), `_createDocumentsDirectories()`
  (Archives/Certificates/Signed/Unsigned), `ResetView.clearWorkCache()`, `_addDefaultCertificates()`
  (imports bundled `signing-assets` first run). App-level singletons spin up: `HeartbeatManager.shared`,
  `DownloadManager.shared`, `Storage.shared` (Core Data).
- **Root view = `VariedTabbarView()`** (`Feather/Views/TabView/VariedTabbarView.swift`) — iOS18+
  `ExtendedTabbarView` else `TabbarView`; tabs = Sources/Library/Settings/Certificates. Trivially
  instantiable. **Only hard dependency: the Core Data context** — `FeatherApp` injects
  `.environment(\.managedObjectContext, Storage.shared.context)`. **No `.environmentObject` anywhere**
  (verified) — every app observable (`DownloadManager`, `OptionsManager`, `SourcesViewModel`, …) is a
  `.shared` singleton used directly in views.

## Fork plan (reuse Delta's ObjC-boundary pattern)

FeatherMode statically links Vapor + ~20 SwiftNIO pkgs + Zsign + OpenSSL + Nuke + Zip + SWCompression,
so a Swift `import FeatherMode` from OpenClaw would fail with **"missing required modules"** exactly
like Delta did. Same fix:

1. **Convert Feather's app target → `Feather.framework`** (module `Feather`) in a fresh clone via a
   Ruby `xcodeproj` script (mirror `Modes/Delta/fork/convert_to_framework.rb`): flip product type;
   framework bundle name == module name; drop the app bridging header; promote `MachOUtils.h` +
   `iconPoc.h` to a **public umbrella** (`Feather.h`); keep `MachOUtils.m`/`iconPoc.m` as sources.
2. **`FeatherHost.swift`** (`@objc` class, added to the target): runs the AppDelegate launch steps
   (pipeline, dirs, default certs, heartbeat) then
   `UIHostingController(rootView: VariedTabbarView().environment(\.managedObjectContext, Storage.shared.context))`.
3. **`FeatherLauncher.h/.m`** (pure ObjC, UIKit-only) → `+ (UIViewController *)makeRootViewController`
   bridging to `[FeatherHost makeRootViewController]`. Add `FeatherLauncher.h` to the umbrella + to
   OpenClaw's existing `Sources/OpenClaw-Bridging-Header.h`.
4. **Stage B**: `ios-build.yml` clones Feather, applies the fork, builds `Feather.framework` +
   whatever dynamic deps otool reports (OpenSSL xcframework, Nuke?, etc.) into `Vendor/FeatherPrebuilt/`
   (cached); `project.yml` embeds them; `ModeSwitcher` gains a `FeatherModeView` + `case "feather"`.
5. **Data isolation**: patch `Extensions/FileManager+documents.swift` to route its 4 helpers through a
   `Documents/Feather/` base, and set `container.persistentStoreDescriptions.first?.url` in
   `Storage.swift` → `Documents/Feather/Feather.sqlite`.

## Risks / open items

1. **OpenSSL collision (defer until UTM).** Zsign pulls `krzyzanowskim/OpenSSL` (libcrypto) as a binary
   xcframework via SPM. UTM mode also needs OpenSSL → two libcrypto copies = dup-symbol / ODR. Converge
   on one shared OpenSSL xcframework (or hidden-visibility per mode) when UTM lands. **No collision for
   Feather alone.**
2. **Vapor/SwiftNIO weight** — the local install server drags ~20 transitive packages (binary size +
   build time), statically linked. The signing core (`FR`, Handlers, `ZsignSwift`) is independent of
   Vapor; trimming the `Backend/Server/` path is possible later if the `itms-services` local server
   isn't wanted.
3. **Bundle identity / entitlements under `ai.openclawfoundation.app`.** `feather://` schemes + `.ipa`/
   `.tipa` exported UTIs, `BGTaskSchedulerPermittedIdentifiers` prefix, `UIBackgroundModes=audio`, and
   the iOS-18 server-install entitlements assume Feather's Info.plist. Merge the needed keys into
   OpenClaw's Info.plist/entitlements or the install/deep-link flows degrade (pairing path still works).
   Hardcoded `"thewonderofyou.Feather.datacache"` (Nuke cache name) is harmless.
4. **GPL-3.0** — confirm with the user before shipping a distributed binary that statically links
   Feather's app layer. [[merge-plan]]

## Verdict

Effort **L**. Closer to Folium than Delta (SwiftUI, no env-object web, standalone build). The only
Delta-flavored bits are the tiny 2-file ObjC boundary and the transitive-module wall — both already
solved by the Delta fork tooling, which this reuses almost verbatim.
