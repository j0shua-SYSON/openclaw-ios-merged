# Mode Embedding — Handoff

Read this before embedding another app as an OpenClaw "mode". It is the cross-cutting playbook;
`Modes/<Mode>/INTEGRATION.md` holds per-mode specifics.

Most of what's here is **not derivable from the code**. It's the residue of ~7 integrations, and
almost every entry in the Crash Catalogue below cost a full build → sign → OTA → device-crash →
`.ips` cycle (~30–40 min each). Reading it is cheaper than rediscovering it.

---

## 1. What this project is

OpenClaw is an iOS app that hides other complete iOS apps inside itself as **modes**, reachable via a
secret gesture (5 taps / 3 fingers). Each mode is a real upstream app — not a reimplementation —
converted into an embeddable framework and presented inside OpenClaw's UI.

Hard target: **stock iOS. No JIT, no jailbreak, no sideload-only entitlements.** If a design needs
any of those, it's the wrong design.

- Repo: `F:\JOSHUA_1st_2021\projects\openclaw_ios_app`
- Working branch: `utm-mode` · Main: `main` · Remote: `j0shua-SYSON/openclaw-ios-merged` (private)
- Distribution: zsign-signed IPA on the `ota` GitHub release, installed over-the-air.

## 2. Non-negotiable constraints

These are the user's, stated verbatim. Violating them is worse than failing the task.

> "never download directly or modify F parent drive itself! only the projects/openclaw_ios_app
> (the directory you are running on)!"

Read from `F:\JOSHUA_1st_2021\projects\*` freely (upstream clones live there). **Write only inside
`openclaw_ios_app`.**

> "my C drive storage is critically low - do not modify, add caches, or install anything on it."

No installs, no caches, no temp files on C:. Staging goes in `openclaw_ios_app\.tmp\` on F:.
`Scripts\sign-local.ps1` already honors this. The session scratchpad is on C: — **don't stage
IPAs there** (they're ~285MB each).

**Working style:** drive autonomously end-to-end. Don't stop to ask "want me to continue?" Ship,
verify, report. Ask only when genuinely blocked on a decision that's the user's to make.

## 4. Architecture — and why

Every mode follows one shape. Deviate only with a reason.

**Upstream app target → `<Mode>.framework`, converted in place.** We do not vendor sources or
rewrite the app. `Modes/<Mode>/fork/` holds a `convert_to_framework.rb` (Ruby `xcodeproj` gem,
flips the app target to a framework) plus an `apply_fork.sh` that applies source patches with
`perl -0pi -e`. CI clones a pinned upstream SHA, runs the fork, builds. **The clone is
runner-only; nothing writes into the OpenClaw repo.** This keeps us rebasable onto upstream.

**The framework name MUST equal the Swift module name.** Clang locates a mixed ObjC+Swift module
by bundle name. `PRODUCT_NAME` = module name, always.

**`@objc` launcher + forward declaration.** Each fork adds a `<Mode>Launcher` compiled *inside* the
mode's own module (so it can touch the mode's internal types). OpenClaw reaches it through a bare
forward declaration in `Sources/OpenClaw-Bridging-Header.h`:

```objc
@interface YatteeLauncher : NSObject
+ (UIViewController * _Nonnull)makeRootViewController;
@end
```

**Never `import <Mode>` from OpenClaw's Swift.** Importing the Clang module makes Swift eagerly load
the same-named Swift overlay and its entire transitive graph (Delta: Roxas/Harmony/SQLite/RevenueCat;
Feather: Vapor/SwiftNIO/OpenSSL; UTM: QEMUKit/CocoaSpice; Yattee: MPVKit/SDWebImage/Siesta) — most
of which ship no module interfaces → "missing required modules". A forward declaration loads no
module at all; the class resolves from the embedded framework at link time via the ObjC runtime.
This is load-bearing, not stylistic.

**Two-stage CI.** `<mode>-build.yml` is a Stage-A validator (clone → fork → build the framework
alone, print diagnostics). Only once green do you wire into `ios-build.yml` + `project.yml` +
`ModeSwitcher.swift`. Stage-A iterations are minutes; full builds are much longer. Use it.

## 5. The playbook

**Stage A — get `<Mode>.framework` building alone.**

Write `Modes/<Mode>/fork/{apply_fork.sh, convert_to_framework.rb, <Mode>Launcher.{swift,h/m}}`,
add `.github/workflows/<mode>-build.yml`, iterate until `** BUILD SUCCEEDED **`.

In Stage-A diagnostics **always print `otool -L` on the framework binary**. That one command decides
the entire packaging story:
- *Only weak/system `@rpath` deps* (Yattee: just `libswift_Concurrency`) → self-contained. Link,
  embed, done.
- *Many `@rpath` deps* (UTM: ~63) → they must be bulk-copied into the bundle post-archive and
  deep-signed. Enormously more work. Know which world you're in before wiring.

Also assert any runtime resource actually landed inside the framework (`.momd`, rootfs, JS blobs).
Prefer a **hard CI failure** over a runtime `fatalError` on the user's device.

**Stage B — wire in.**

1. `Sources/OpenClaw-Bridging-Header.h` — forward-declare the launcher.
2. `Sources/ModeSwitcher.swift` — a `<Mode>ModeView: UIViewControllerRepresentable`, a `case "<id>"`
   in `ModeContainerView`, and a registry tile.
3. `project.yml` — `- framework: Vendor/<Mode>Prebuilt/<Mode>.framework` + `embed: true`.
4. `.github/workflows/ios-build.yml` — restore-cache / build / save-cache steps producing
   `Vendor/<Mode>Prebuilt/`. **Key the cache on the upstream SHA + `hashFiles('Modes/<Mode>/fork/**')`**
   so fork edits invalidate it automatically. Getting this wrong means testing a stale framework and
   chasing a ghost.

Then build → sign → OTA → **verify on device**. A green build proves nothing about runtime; see §6.

## 6. Crash catalogue — the expensive lessons

### 6.1 `Bundle.main` is OpenClaw. This is THE recurring bug class.

Embedded, a mode's `Bundle.main` resolves to the **host app**, which has none of the mode's
resources. Every mode has hit this. Grep each new upstream for `Bundle.main`, `.main`,
`mainBundle`, `NSPersistentContainer(name:)`, `UIImage(named:)`, `NSLocalizedString` **before**
the first device run. Known instances:

| Symptom | Cause | Fix |
|---|---|---|
| Crash opening UTM Settings | IASK reads `Settings.bundle` from `mainBundle` | `+load` swizzle of `-[IASKSettingsReader initWithFile:]` → `initWithFile:bundle:` |
| Crash creating a VM | `UIImage(named:)!` returns nil | swizzle `+[UIImage imageNamed:]`, main-bundle first then framework fallback |
| Yattee `fatalError` on store load | `NSPersistentContainer(name:)` resolves `.momd` from `Bundle.main` only | load the model from the framework bundle (`Bundle(for: BundleToken.self)`) |
| Translations silently missing | `NSLocalizedString(bundle: .main)` | point at the framework bundle |

Pattern for the swizzles: `Modes/UTM/fork/UTMOpenClawBundleFix.m`.

**SPM packages are structurally immune** — they use `Bundle.module`. Xcode app targets are not.
An upstream shipped as a Swift package is a materially easier embed.

### 6.2 Swift `static let` is a `dispatch_once` — re-entrancy traps

Yattee died with `EXC_BREAKPOINT` / "BUG IN CLIENT OF LIBDISPATCH: trying to lock recursively".
Chain: `PlayerModel.shared` (once begins, main thread) → `init()` → `currentRate` `didSet` →
`handleCurrentRateChange()` → `backend.setRate()` → `AVPlayer.setRate:` → fires KVO **synchronously**
→ observer closure reads `self.model` → `var model: PlayerModel { .shared }` is **computed** →
re-enters the once **on the same thread** → trap.

Generalize: **if a singleton's `init()` can synchronously reach code that reads the same singleton,
it traps.** KVO, notifications and delegate callbacks are the usual couriers, because they fire
synchronously and look inert at the call site.

Note what actually caused it: **our own patch**, not upstream. Upstream defaulted to `.mpv`, which
routes `setRate` to a backend that touches no AVPlayer KVO — it escaped by ordering luck. Forcing
`activeBackend = .appleAVPlayer` (to honor a user preference) armed the loop, and it bought nothing,
because Yattee picks the backend per-video from `QualityProfile` and assigns `activeBackend` via
`changeActiveBackend()` anyway. **Before patching a default, find out whether it's authoritative or
merely transient.** `Modes/Yattee/fork/apply_fork.sh` §5 has the full write-up plus guards.

### 6.3 Framework conversion fallout

- **`@main` is illegal in a framework.** Neutralize it, then reproduce whatever the `App` struct did
  (Yattee's `configure()`: image pipeline, account/instance setup, foreground/background forwarding)
  inside the launcher. It is easy to neutralize `@main` and silently lose all startup work.
- **A framework can't use `SWIFT_OBJC_BRIDGING_HEADER`.** Dropping it removes *implicit* imports —
  files that relied on it for Foundation/ObjC break with "cannot find type 'NSObject' in scope"
  (Yattee's `NSObject+Swizzle.swift`). Re-add explicit imports.
- **Frameworks emit only the PUBLIC `<Module>-Swift.h`.** Internal `@objc` members become invisible
  to the module's own ObjC, which cascades into public-ification. Promote at **member level**, not
  file level (UTM's `UTMQemuPort.swift` needed protocol-conformance members public; took 11
  iterations). See `Modes/UTM/fork/apply_fork.sh` §2b/§2c.

### 6.4 Toolchain / environment

- **Xcode 26 on CI is stricter than the user's local Xcode.** Unused function-typed result = hard
  error (not a warning; `SWIFT_TREAT_WARNINGS_AS_ERRORS=NO` won't save you — assign to `_`).
  Cross-file `private(set)` is rejected → `internal(set)`.
- **`#if` is not permitted as an array-literal element in Swift** — "expected expression in
  container literal". Why the UTM registry tile is unconditional while its view/case are `#if`'d.
- **Sanitizers can come from the scheme**, not build settings. UTM's ASan survived
  `ENABLE_ADDRESS_SANITIZER=NO`; it was `enableAddressSanitizer="YES"` in the `.xcscheme`. `sed` the
  scheme.
- **Ghidra** (`F:\JOSHUA_1st_2021\projects\ios_bounty_research\...`): spaces in filenames split
  args; paths starting with `.` are rejected; `.py` postScripts need PyGhidra (use Java); analysis
  can exceed 2400s.

### 6.5 UI / touch handling

- **SwiftUI `.fileImporter` misbehaves inside nested `UIHostingController`s** — the picker appears
  but selection is inert. Use UIKit `UIDocumentPickerViewController` ("**the Feather method**" —
  Feather's picker works, and it's the one that has an explicit *Open* button). The user diagnosed
  this: *"feather file picker works fine… the ones that don't work have automatic file picking."*
  Still **open for UTM.**
- Mode UI must not eat the switcher gesture: `PassthroughGestureView` (`hitTest → nil`) +
  window-re-homed recognizers with `cancelsTouchesInView = false` = observe-only.

## 7. Build / sign / OTA runbook

```bash
# Build (UTM off = fast: ~262MB, ~2min sign. UTM on: ~471MB, ~30min sign)
gh workflow run ios-build.yml --ref utm-mode -f include_utm=false

# Stage on F: (NOT the C: scratchpad — ~285MB)
gh release download ci-unsigned --pattern "OpenClaw-unsigned.ipa" --dir .tmp --clobber
```
```powershell
.\Scripts\sign-local.ps1     # zsign, deep-signs nested frameworks
```
```bash
cp .tmp/OpenClaw-unsigned-signed.ipa .tmp/OpenClaw-signed.ipa
gh release upload ota .tmp/OpenClaw-signed.ipa --clobber
# ALWAYS verify — see below
gh release view ota --json assets --jq '.assets[] | "\(.name)\t\(.size)\t\(.state)"'
curl -sIL -o /dev/null -w "%{http_code}\n" \
  https://github.com/j0shua-SYSON/openclaw-ios-merged/releases/download/ota/OpenClaw-signed.ipa
```

**Two traps that produced "Unable to Install":**

1. **zsign defaults to store (no compression).** The UTM build made a **2.35GB** IPA; GitHub's
   release asset cap is **2GB** → HTTP 422. `-z 9` → 480MB. Already in `sign-local.ps1`; don't
   remove it.
2. **`gh release upload --clobber` deletes the existing asset first.** A failed upload therefore
   leaves the asset **missing**, and the manifest 404s. Always re-verify the asset is present and
   the URL returns 200 after uploading. `manifest.plist` points at `OpenClaw-signed.ipa` — keep
   that filename stable and the manifest stays valid.

**A green build proves nothing about runtime.** Every mode so far built green and then crashed on
device. When it crashes, ask for the `.ips` — they're excellent. Parse: split off the first line
(JSON header), the rest is the payload; read `exception`, `asi` (libdispatch/Swift runtime messages
land here), and `threads[faultingThread]`. The Yattee deadlock gave up its entire causal chain in
one stack.

## 8. Mode status (2026-07-17)

| Mode | State |
|---|---|
| Delta, Folium, Feather, iSH | Shipping. Delta wants a re-verify on device after its crash fix. |
| SmartTube | Shipping. Vendored at `Vendor/SmartTube/` (user's local known-good copy — the public repo's master is WIP-broken and the user's good SHA was never pushed). Firebase stripped, `.swiftLanguageMode(.v5)`. User calls it "very unstable and buggy"; kept deliberately alongside Yattee for an independent failure mode. Forced onto its web player — the native path doesn't play on iOS (why upstream forces the web player). |
| Yattee | Just fixed the §6.2 deadlock; OTA shipped; **awaiting device verification.** |
| UTM SE | Builds, runs, both crashes fixed — but **flagged off** (`-f include_utm=false`) for build speed. Returns in the final build. **Owes the §6.5 picker fix.** |
| DolphiniOS | Never started. |

## 9. Open work

1. **Verify Yattee on device.** If it launches but feeds/playback are empty, that's the seeded
   Invidious instance, not the embed (see §10).
2. **UTM file picker → the Feather method** (§6.5), then the final `-f include_utm=true` build.
4. DolphiniOS.

## 10. Yattee's structural fragility — flag it, don't "fix" it

Yattee has **no direct-YouTube path**. It plays only through an Invidious/Piped instance. At the
time of writing, `inv.zoomerville.com` was the **only** public Invidious instance still serving
HTTPS with its API enabled — YouTube has blocked essentially all the others. It's seeded on first
run (`YatteeLauncher.seedDefaultInstanceIfNeeded()`).

If that instance is rate-limited or dies, Yattee goes dark until the user adds a live or
self-hosted instance in **Settings ▸ Locations**. **No embedding work can fix this** — it's
upstream's architecture. Don't burn hours debugging the embed when the instance is what's down.
This is exactly why SmartTube stays: it fails independently. The user knows and chose both
("*yeah. just keep both*").

Instance lists: <https://api.invidious.io/> ·
<https://github.com/TeamPiped/documentation/blob/main/content/docs/public-instances/index.md>
