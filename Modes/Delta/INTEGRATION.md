# Delta mode — integration notes

Source: upstream `rileytestut/Delta` @ `adee3c5` (v1.6-315). Cloned by CI only (never on local F:).

## Validated

- **Delta's full workspace BUILDS on our Xcode 26 CI** — app + 8 cores + Roxas + Harmony + Pods +
  the SPM packages (rcheevos, RevenueCat, AltKit, KeychainAccess, ShowTouches). ~9 min, clean.
  Workflow: `.github/workflows/delta-build.yml`. **Feasibility of building Delta is proven.**

## Component map

| Piece | How it builds | Notes |
|-------|---------------|-------|
| DeltaCore | **SPM** (`Package.swift`, dep ZIPFoundation) | the emulation API layer |
| 7 emulator cores (NES/SNES/N64/GBC/GBA/MelonDS/GPGX) | `.xcodeproj` frameworks | wrap C/C++ cores (nested submodules) |
| Roxas, Harmony | `.xcodeproj` frameworks (also path-pods) | ObjC utility + sync |
| App layer (`Delta/`) | app target, **Swift 5.0**, CocoaPods | SDWebImage **3.8** (can't swap to modern SPM), SQLite.swift 0.12, SMCalloutView + 5 SPM pkgs |

App target settings: `SWIFT_VERSION=5.0`, `SWIFT_ACTIVE_COMPILATION_CONDITIONS=BETA` (registers all
cores incl. Genesis), `SWIFT_OBJC_BRIDGING_HEADER=Delta/Supporting Files/Delta-Bridging-Header.h`,
`OTHER_LDFLAGS=-ObjC`, storyboards (Main/Settings/PauseMenu/…), Core Data (`Delta.xcdatamodeld`).

## The wall: app-layer → framework

OpenClaw is **Swift 6 strict-concurrency**; Delta is **Swift 5**. You cannot mix language modes in
one target, so Delta's app code must live in its **own framework/target** linked by OpenClaw.
But that target can't be the app's own target because:
- **Frameworks cannot use an Obj-C bridging header** (Xcode disallows it). Delta's Swift relies on
  `Delta-Bridging-Header.h` to see Roxas / pod / internal ObjC symbols without `import`. Converting
  → add explicit `import Roxas` etc. across many files, and expose internal ObjC via an umbrella header.
- `@UIApplicationMain` + storyboard-as-app must be neutralized (present `LaunchViewController`
  manually instead of via `UIMainStoryboardFile`).
- Its app code / cores must build in the **CocoaPods context** (SDWebImage 3.8), so DeltaMode is built
  inside Delta's own workspace (Stage A), then embedded prebuilt into OpenClaw (Stage B).

This is a genuine **fork of Delta's app layer**, not a repackage — the "XL" originally flagged.

## Two honest paths

**A. Full Delta (the real app UI).** Do the app-layer→framework fork above: resolve the bridging
header, neutralize app-entry, build DeltaMode.framework in Delta's Pods workspace, embed in OpenClaw,
present `GamesViewController`. Large, iterative. Delivers Delta's real library/settings/save-states/
cheats/skins.

**B. Delta cores + native OpenClaw UI.** Embed only **DeltaCore (SPM) + the core frameworks** (which
build cleanly as frameworks, no bridging-header issue) and write a lean SwiftUI emulator front-end in
OpenClaw. Medium effort. Delivers Delta's *emulation* of all systems, but **not** Delta's own UI.

## Recommendation

Path A is what "embed Delta" really means, but it's the single largest task in the project and the
bridging-header fork is fiddly. If the goal is a *working emulator mode soonest*, **Folium is far
cleaner** (Swift 6, SPM, framework-ready, no bridging header) — hence the original "Folium first".
Decision pending from the user.
