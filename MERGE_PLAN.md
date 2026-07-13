# OpenClaw × Emulators — Merge Plan

**Goal:** One installed iOS app that launches as **OpenClaw** (unchanged identity/bundle id
`ai.openclawfoundation.app`). A secret gesture — **5 rapid taps with 3 fingers** — toggles a
hidden panel (a **switcher list**). Tapping an entry switches the whole app to that "mode."
The same gesture hides the panel. Each mode keeps its own **isolated file directory**.

**Target runtime:** stock iOS, **no JIT, no jailbreak, no TrollStore**. Signed with the user's
own certificate. Builds happen **only on GitHub Actions macOS runners** (the dev machine is
Windows). Nothing is written to the C: drive locally.

**Embedded modes (scope, locked):** Delta, iSH, Feather, DolphiniOS, UTM **SE**, Folium.
Dropped: LiveContainer, SideStore, SideInstaller, PPSSPP, MeloNX, Provenance, iDOS.

**Repo:** `j0shua-SYSON/openclaw-ios-merged` (private). CI build → `ci-unsigned` release; signed → `ci-signed`.

---

## Status (updated 2026-07-13)

- **Phase 0 ✅** — self-contained OpenClaw builds green in CI (Xcode 26, Swift 6, SPM traits, WebRTC, watch + extensions). Unsigned IPA (~29.7 MB) published to the `ci-unsigned` release. `Re-sign IPA` workflow ready (needs the 3 signing secrets).
- **Phase 1 ✅** — hidden mode switcher live: window-level 5-tap/3-finger recognizer, switcher panel listing all 6 modes, per-mode `Documents/<mode>/` isolation, placeholder mode container. Compiles + ships in CI (`Sources/ModeSwitcher.swift` + `OpenClawApp` wiring).
- **Phase 2 ⏳** — Folium (next): vendor `../AntiqueKit` + `~/Downloads/TPCircularBuffer`, build its 4 C++ cores (Grape/Kiwi/Mandarine/Tomato), symbol-isolate vs future melonDS in Delta, present `GamesController`, redirect data to `Documents/Folium/`.

---

## 1. Systems the finished app would cover

| Source        | Systems / capability                                             | Jitless? |
|---------------|-----------------------------------------------------------------|----------|
| **Delta**     | NES, SNES, N64\*, GB/GBC, GBA, DS\*, Genesis                     | Yes (N64/DS slow) |
| **Folium**    | DS, **PS1**, GB/GBC, GBA (3DS core is an unshipped stub — drop)  | Yes |
| **iSH**       | x86 Linux shell (Alpine)                                         | Yes (interpreter) |
| **UTM SE**    | Full VMs (x86/ARM Linux, etc.) via QEMU TCTI                     | Yes (slow) |
| **DolphiniOS**| GameCube / Wii                                                  | Yes (Cached Interpreter, **slow** — light GC only) |
| **Feather**   | On-device IPA signing + install (your p12 + mobileprovision)    | n/a |

\* N64 and DS run via interpreter without JIT — functional but below full speed.

**Overlap to manage:** Delta and Folium both ship **melonDS** (DS) and both do GB/GBC + GBA →
duplicate C/C++ symbols if naively linked (see §4). Folium uniquely adds **PS1**.

---

## 2. Per-app analysis summary

Every app's emulator submodules/sources were checked. Verdicts assume the no-JIT host.

### Delta — effort **XL**
- Build: `Delta.xcworkspace` + **CocoaPods (committed)** + **12 uninitialized submodules**
  (7 on `git@github.com:` SSH URLs, nested C/C++ cores) + **Git LFS** + a `Systems/build.sh`
  phase producing `Systems.framework` to dodge a DeltaCore Pods-vs-SPM double-link.
- Entry: `@UIApplicationMain` → `AppDelegate.swift`; storyboard initial VC `LaunchViewController`
  → library screen **`GamesViewController`** (`Delta/Game Selection/`).
- JIT: none required. NES/SNES/GB/GBA/Genesis full speed; N64 + DS slow-but-functional.
  Register all cores incl. Genesis via the **`BETA`** compilation flag.
- Entitlements: **`Delta.entitlements` is empty** — nothing to merge. Big win.
- Data isolation: one override — `DatabaseManager.defaultDirectoryURL()` → `Documents/Delta/`.
  (Core-internal BIOS/save paths inside `*DeltaCore` need re-pathing once cores are fetched.)
- Collisions: **SDWebImage 3.8** (vs Folium 5.x), **melonDS** (vs Folium), SQLite.swift 0.12,
  Alamofire 4, zlib.

### Folium — effort **L**  ← cleanest emulator
- Build: native `Folium.xcodeproj` (Xcode 26 file-synced groups), **SPM only**, **no submodules,
  no LFS**. iOS **18.0**, **Swift 6.0**. Cores are Swift **actors** wrapping C++ static libs
  (`libGrape/Kiwi/Mandarine/Tomato.a`) via direct C++ interop; software-rendered (CPU → CGImage
  → UIImageView), **no Metal** for shipping cores.
- Shipping cores all jitless: **Grape=NDS (melonDS, interpreter-only)**, **Kiwi=GB/GBC (Gambatte)**,
  **Mandarine=PS1 (Avocado)**, **Tomato=GBA (NanoBoyAdvance)**. **Cytrus=3DS is an empty stub —
  not wired up — drop it.**
- Entry: `@main AppDelegate.swift`; `SceneDelegate` is composition root → `TabController`
  (UITabBarController) → **`GamesController`** grid.
- Entitlements: **none at all** — nothing ungrantable. Clean.
- Data isolation: **S** — insert a `Folium/` path component in the 4 per-core base URLs.
- Blockers: two deps live **outside the repo** (`../AntiqueKit`, `~/Downloads/TPCircularBuffer`)
  and are absent on F:; SharedDependencies fetches SDL3/fmt/teakra/FLAC/ogg/OpenSSL/zstd
  xcframeworks from GitHub releases. Vendor those. melonDS/SDL/OpenSSL collide with other modes.

### iSH — effort **L→XL**
- Build: `iSH.xcodeproj` whose run-script phases drive **Meson/Ninja** + hand-written **aarch64
  gadget assembly** → static libs (`libish.a`, `libish_emu.a`, `libfakefs.a`). ObjC UI + C core,
  **no Swift**. 3 uninitialized submodules (`libapps` hterm UI, `libarchive`; skip `linux`).
- JIT: **none** — threaded interpreter (no `MAP_JIT`). Confirmed stock-iOS-safe.
- Entry: `main.m`/`AppDelegate.m`; present **`TerminalViewController`** (WKWebView + hterm).
  Drop the FileProvider extension; stub `-syncFileProviderDomains`.
- Entitlements: app-group + user-fonts, both **removable** once the extension is dropped.
- Data isolation: one chokepoint — `RootsDir()` (`app/Roots.m`) → `Documents/iSH/`.
- Blockers: Alpine **rootfs** is curl-downloaded at build time and bundled; first-launch import
  into the isolated dir (off main thread). Many **un-prefixed C globals** (`current`, `task_start`,
  …) must be symbol-isolated. Boots one process-wide "kernel" and calls `exit(0)` on background —
  needs lazy boot-on-entry + lifecycle rework.

### UTM SE — effort **L→XL**
- Build: single `UTM.xcodeproj`; QEMU arrives as **prebuilt `.framework`s** (a downloaded
  `sysroot-*`, hundreds of MB) — **not** built from the tree. QEMU wrapped by the **QEMUKit** SPM
  package; SPICE via CocoaSpice. Use the **`iOS-SE` scheme** (`WITH_QEMU_TCI`, `-TCI` sysroot).
- JIT: **none** for SE (TCTI threaded interpreter). Never build the JIT `iOS` scheme.
- Entry: `@main` `Platform/Main.swift` → SwiftUI `UTMApp`; present **`UTMSingleWindowView`** in a
  `UIHostingController`.
- Entitlements: only `increased-memory-limit` + `extended-virtual-addressing` — both **grantable
  to a paid dev cert** (must be enabled on the App ID / provisioning profile).
- Data isolation: **S** — `UTMData.defaultStorageUrl` → `Documents/UTM/`.
- Blockers: giant external QEMU/SPICE/**ANGLE**/OpenSSL frameworks (size + symbol collisions);
  `WITH_SOLO_VM` + QEMU never cleans up in-process ⇒ **one VM per app launch** (lifecycle caveat).

### DolphiniOS — effort **XL**
- Build: ~2,000-file **C++23** core via a bolt-on **CMake/Ninja** (`BuildCore.sh`) → `dolphin`
  dylib; iOS app `DolphiniOS.xcodeproj` links it. **28 uninitialized submodules**; committed
  `MoltenVK.xcframework`. Schemes **DiOS (NJB)** / (JB) — use **NJB**.
- JIT: this fork has a **real no-JIT Cached Interpreter** path (no executable memory, no
  ungrantable entitlement) — **but slow** (light GameCube only; Wii/heavy GC not enjoyable).
- Entry: `main.m`/`AppDelegate.swift`; present **`SoftwareListViewController`** (game list).
- Entitlements: `increased-memory-limit` (paid cert). No app groups. Private JB entitlements are
  used only by the JB scheme — ignore.
- Data isolation: one function — `UserFolderUtil.getUserFolder()` → `Documents/Dolphin/`.
- Blockers: huge C++ build; **Firebase/Crashlytics telemetry must be stripped**; AltKit dropped;
  bundles SDL/mbedtls/zlib-ng/curl/fmt (collisions); global singletons + 16 GiB fastmem
  reservation + Metal surface handoff make clean teardown on mode-switch fragile.

### Feather — effort **L**
- Build: `Feather.xcworkspace` (app + local SPM pkgs AltSourceKit/NimbleKit + submodules **Zsign**,
  **IDeviceKitten**), SwiftUI, iOS 16+, Swift 6. `make` → IPA. Needs `make deps` (backloop.dev
  TLS cert for the local HTTPS server).
- Function: signs IPAs with **your `.p12` + `.mobileprovision`** via Zsign, installs via a local
  **Vapor HTTPS server** (`itms-services://`) or a **pairing/heartbeat** path (IDeviceKitten).
  No Apple-ID/anisette. Works embedded (doesn't need to be the main installed app).
- Entry: `FeatherApp.swift` (+ AppDelegate); handles `feather://` schemes.
- Data isolation: Core Data + files → redirect to `Documents/Feather/`.
- Blockers: Vapor/SwiftNIO weight; **Zsign→OpenSSL** collides with UTM's OpenSSL; **GPL-3.0**.

---

## 3. Architecture

**Host stays OpenClaw.** `@main OpenClawApp → WindowGroup { RootTabs() }` is untouched at launch.
Each embedded app becomes a **mode**, not a co-linked pile of source.

```
OpenClaw.app (bundle id ai.openclawfoundation.app)
├─ OpenClaw host (SwiftUI)            ← launches normally
│   ├─ SecretGestureRecognizer        ← 5 taps / 3 fingers on the key window
│   ├─ ModeSwitcherPanel (overlay)    ← hidden; toggled by the gesture
│   └─ ModeHost                       ← presents/tears down a mode's root VC full-screen
├─ Modes (each its own dynamic .framework, symbols hidden)
│   ├─ DeltaMode.framework            → GamesViewController
│   ├─ FoliumMode.framework           → TabController/GamesController
│   ├─ iSHMode.framework              → TerminalViewController
│   ├─ UTMSEMode.framework            → UTMSingleWindowView (hosting controller)
│   ├─ DolphinMode.framework          → SoftwareListViewController
│   └─ FeatherMode.framework          → FeatherApp root view
└─ Per-mode data dirs: Documents/{Delta,Folium,iSH,UTM,Dolphin,Feather}/
```

### 4. Symbol isolation (the linchpin for "one binary, not curated")
Multiple modes bundle the same native libraries (melonDS in Delta+Folium; SDL/OpenSSL/zlib/FLAC
across several). To avoid ODR/duplicate-symbol failures, **each mode is built as its own dynamic
framework with non-exported (hidden-visibility) symbols**, linking its own copy of its C/C++ deps
privately. Only one mode is active at a time, so runtime footprint stays bounded. Shared *system*
libraries (libsqlite3, libz, libc++) use the OS copy. Where two modes must share a heavy lib, we
de-dup to a single vendored copy. This is what makes "keep both melonDS providers" possible.

### 5. Data isolation (per-app directories in Files)
Every app has a **single path chokepoint** (verified per app above). We override each to a
dedicated `Documents/<Mode>/` subfolder. We keep `UIFileSharingEnabled`/document-browser **off**
at the host, so the Files-app surface is the host's, and each mode's data is neatly namespaced.

### 6. Secret gesture + panel
- A `UITapGestureRecognizer` with `numberOfTapsRequired = 5`, `numberOfTouchesRequired = 3`,
  installed on the key window (survives across the host and any presented mode).
- Toggles a SwiftUI overlay `ModeSwitcherPanel` (hidden by default). The panel lists OpenClaw +
  the available modes; selecting one calls `ModeHost.present(mode)`. Re-doing the gesture hides it.
- `ModeHost` lazily initializes the chosen mode (bootstrap, data-dir redirect), presents its root
  VC full-screen, and tears it down on exit (respecting per-app lifecycle caveats — iSH kernel,
  UTM solo-VM, Dolphin singletons).

---

## 7. Build & signing (GitHub Actions)

**Repo:** make `openclaw_ios_app` self-contained (Phase 0): vendor `OpenClawKit` + `Swabble`
(both have only fetchable remote SPM deps), fix the two `path:` lines in `project.yml`, and drop
the swiftformat/swiftlint pre-build phases (they need monorepo `scripts/`+`config/`). WebRTC is a
remote SPM package. Then `xcodegen` + `xcodebuild` build it.

**Workflow A — build (`.github/workflows/ios-build.yml`, `macos-15` runner):**
1. Checkout (with submodules/LFS for whichever modes are in the build).
2. Install `xcodegen`; rewrite Delta submodule SSH URLs → HTTPS; fetch mode deps/sysroots.
3. `xcodegen generate`; `xcodebuild archive` (no signing: `CODE_SIGNING_ALLOWED=NO`).
4. Export an **unsigned** `.ipa`; upload as a build artifact.

**Workflow B — re-sign (`.github/workflows/ios-resign.yml`, `workflow_dispatch`):**
Inputs (uploaded by the user): unsigned `.ipa`, `.p12`, `.mobileprovision`, and the p12
**password** (as a secret). The job imports the cert into a temp keychain, applies the provisioning
profile + entitlements (`increased-memory-limit` + `extended-virtual-addressing` for UTM/Dolphin),
re-signs, and emits the **signed `.ipa`** as an artifact to install. No certs are stored in the
repo; nothing touches the local machine.

---

## 8. Phased roadmap

| Phase | Deliverable | Risk | Effort |
|-------|-------------|------|--------|
| **0** | Self-contained OpenClaw builds green (unsigned IPA) in CI; **re-sign workflow** works end-to-end (you can install vanilla OpenClaw). | Low | S–M |
| **1** | Secret gesture + switcher panel + `ModeHost` in OpenClaw, tested with a placeholder mode. Per-mode data-dir helper. | Low | M |
| **2** | **First real emulator = Folium** (cleanest: SPM, iOS 18, Swift 6, no entitlements, no submodules, jitless, adds NDS/PS1/GB/GBC/GBA). Proves the framework-mode + symbol-isolation + data-isolation pattern. | Med | L |
| **3** | **Delta** (headline: NES/SNES/N64/GB/GBA/DS/Genesis). Submodule+LFS+CocoaPods bring-up; melonDS de-dup vs Folium. | High | XL |
| **4** | **Feather** (on-device signing/install with your cert). | Med | L |
| **5** | **iSH** (Meson/assembly core + rootfs bootstrap). | High | L–XL |
| **6** | **UTM SE** (prebuilt QEMU `-TCI` frameworks; solo-VM lifecycle). | High | L–XL |
| **7** | **DolphiniOS** (C++23/CMake core; slow no-JIT GC). Last — highest cost, lowest payoff. | High | XL |

Each phase is independently CI-built and installable. Modes can ship incrementally.

---

## 9. Risks & honest caveats
- **Scale:** this is a large, multi-week program; several modes are XL. Most of it can only be
  validated by building on CI (macOS) and installing — not on the Windows dev box.
- **Performance (no JIT):** N64/DS (Delta), UTM SE, and especially **DolphiniOS** are slow. Good
  for light content/testing, not full-speed for demanding titles.
- **Licensing:** the combined binary mixes **AGPL-3.0 (Delta)**, **GPL-3.0 (Feather, iSH)**,
  **GPL-2.0 (Dolphin/QEMU)**, Apache (UTM). Fine for personal sideloading; **redistribution** would
  make the whole app copyleft and raises GPL-2/3 compatibility questions. Personal use assumed.
- **Paid cert:** UTM SE and DolphiniOS want `increased-memory-limit` (paid Apple dev account +
  the capability on the App ID). Without it they still launch but are memory-limited.
- **Telemetry:** DolphiniOS Firebase/Crashlytics must be stripped for privacy.
- **Lifecycle:** iSH (process-wide kernel + `exit(0)`), UTM (one VM per launch), Dolphin
  (singletons + GPU surface) each need careful mode-enter/exit handling.
