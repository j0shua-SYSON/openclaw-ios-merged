# UTM SE mode integration

Embed [UTM SE](https://github.com/utmapp/UTM) (`utmapp/UTM`, Apache-2.0) as a hidden
OpenClaw mode: full-system QEMU virtual machines, JIT-less ("SE" = the TCTI / Tiny Code
Threaded Interpreter path, `ios-tci`), so it runs on stock iOS. This is the **largest and
hardest** embed of the six by a wide margin — a desktop-class VM app wrapping QEMU + a
huge native dependency tree.

## Decision: prebuilt QEMU (from UTM-SE.ipa), not built-from-source

`scripts/build_dependencies.sh -p ios-tci` compiles QEMU + glib + spice + gstreamer + …
entirely from source; UTM throttles it to **1 CPU due to OOM** and it takes hours — real
risk it won't fit a GitHub-hosted runner (7 GB / 6 h). So we reuse UTM's **official
prebuilt `UTM-SE.ipa`** release binaries instead (user-approved). Trade-off: pinned to a
UTM release, and we still must build UTM's app layer from source (see the sysroot crux).

## What's inside UTM-SE.ipa (v5.0.3, 208 MB)

`Payload/UTM SE.app/`:
- **`UTM SE`** — the app-layer binary (7.7 MB, Swift/ObjC). An *executable*, so it can't be
  embedded directly; the app layer must be rebuilt as a framework.
- **`Frameworks/` (~60):**
  - 7 QEMU cores: `qemu-{aarch64,x86_64,i386,m68k,ppc,ppc64,riscv64}-softmmu.framework`
  - deps: `glib-2.0`, `gobject/gio/gmodule/gthread`, `pixman-1`, `spice-{client-glib,server}`,
    `gstreamer-1.0` + 14 gst* libs, `MoltenVK`, `vulkan.1`, `virglrenderer.1`, `epoxy`,
    `EGL`/`GLESv2`, `crypto.1.1`/`ssl.1.1`, `gcrypt`/`gpg-error`, `ffi.8`, `iconv`/`intl`,
    `jpeg`/`png16`, `json-glib`, `opus`, `phodav`, `slirp`, `soup-3.0`, `swtpm`, `zstd`, …
- **resources:** `qemu/` (BIOS/firmware: `bios-256k.bin`, dtbs, `edk2-*`), `vulkan/`,
  `CocoaSpice_CocoaSpiceRenderer.bundle`, `InAppSettingsKit`/`ZIPFoundation` bundles,
  `Assets.car`, `Settings.bundle`, localizations, `Metadata.appintents`.

## The crux: the sysroot headers — RESOLVED

The prebuilt IPA has the **libs** but not the **headers** UTM's app layer compiles against.
Turns out UTM's CI **uploads the whole sysroot** (`include/` + `lib/` + `Frameworks/`) as a
downloadable artifact `Sysroot-ios-tci-arm64`. We grabbed it (run 25291766660, UTM SHA
`e4a4c34b671284263fc69f81b607de494d7e9b65`) and **re-hosted it in our own repo** —
release `utm-sysroot`, asset `sysroot.tgz` (385 MB) — because the upstream artifact expires
2026-08-01. Verified layout: `sysroot-ios-tci-arm64/{include,lib,Frameworks,bin,host,share,...}`
with real headers (qemu-plugin.h, glib, spice-client-glib) and the compiled QEMU/dep
frameworks. So the prebuilt path is fully viable and the app-layer build has everything it needs.

**Pin UTM to `e4a4c34`** (the sysroot's SHA) so the app layer's headers/ABI match. Our CI
downloads the sysroot from our `utm-sysroot` release (same-repo, stable), extracts it to the
UTM clone root, then runs `build_utm.sh`-equivalent against scheme `iOS-SE`.

## Milestones (each a CI iteration on utm-mode)

0. ✅ Research: map UTM-SE.ipa, pick the prebuilt path. (this doc)
1. ✅ Sysroot: downloaded UTM's `Sysroot-ios-tci-arm64` artifact + re-hosted as our
   `utm-sysroot` release (385 MB). Headers + QEMU/dep libs confirmed present.
2. **App layer builds — ✅ 2a done.** Validated `xcodebuild archive -scheme iOS-SE` against our
   sysroot on macos-15 / **Xcode 26** → `** ARCHIVE SUCCEEDED **`, `UTM SE.app` with all ~60 QEMU/dep
   frameworks embedded from the sysroot. (Notes: the sysroot dir matches case-insensitively —
   our `sysroot-ios-tci-arm64` vs the project's `sysroot-iOS-TCI-arm64`; `xcodebuild archive`
   prints `ARCHIVE SUCCEEDED`, not `BUILD SUCCEEDED`.)
   **2b (next):** convert the `iOS-SE` app target → `UTMSE.framework`. It's a standard
   `product-type.application` with phases: Generate-Info.plist / Sources / Frameworks / Resources /
   Patch-Settings / **Embed Libraries**. Conversion: flip product type; **drop "Embed Libraries"**
   (the ~60 QEMU/dep frameworks go into OpenClaw's `Frameworks/`, not nested in UTMSE.framework);
   neutralize the SwiftUI `@main` app entry; add a `UTMLauncher` returning UTM's root VC via
   UIHostingController (Feather pattern). UTM SE runs QEMU in-process via dlopen (iOS can't spawn
   processes), which suits embedding.
### M2b convert spec (mapped; convert_to_framework.rb is the iterative piece)

Target `iOS-SE` (`CEA45E1F263519B5002FA97D`): `PRODUCT_NAME "UTM SE"`, `PRODUCT_MODULE_NAME UTM`,
`SWIFT_OBJC_BRIDGING_HEADER Services/Swift-Bridging-Header.h`. Entry `@main class Main`
(Platform/Main.swift) → `Main.main()` → (JIT block skipped for SE) → `UTMPatches.patchAll()` +
`registerDefaultsFromSettingsBundle()` + `Tips.configure()` → `UTMApp.main()`; root =
`UTMSingleWindowView(data: UTMData())`.

Conversion (mirrors Delta):
- product-type application → framework; **PRODUCT_NAME = UTM** (framework name MUST equal the
  Clang/Swift module name `UTM`, or "missing module UTM"); keep PRODUCT_MODULE_NAME = UTM.
- MACH_O_TYPE mh_dylib, DEFINES_MODULE YES, INFOPLIST_FILE UTMMode-Info.plist, code-signing off,
  @rpath install name.
- **Neutralize `@main`** in Platform/Main.swift (illegal in a framework) — comment the attribute;
  `Main.main()` is never called (we boot via UTMLauncher).
- **Drop the "Embed Libraries" copy phase** (`CEA45F71…`, dstSubfolderSpec 10 = Frameworks): the
  ~60 QEMU/dep frameworks go into OpenClaw's Frameworks/, not nested inside UTM.framework.
- ✅ **UTMLauncher.swift** written (the @objc boundary + non-JIT setup + UTMSingleWindowView root).
- **The crux — bridging header → umbrella:** frameworks can't use SWIFT_OBJC_BRIDGING_HEADER.
  Services/Swift-Bridging-Header.h `#include`s ~30 of UTM's own ObjC headers (UTMQemuSystem,
  UTMProcess, VMDisplayMetalViewController, the UTMLegacyQemuConfiguration family, …), several of
  which pull non-modular C/QEMU headers. Remove the bridging-header setting and expose those via a
  framework umbrella + public Headers phase — expect "non-modular include in framework module" /
  "missing required modules" iterations (Delta hit the same class). This is the make-or-break of 2b.

   **2b — ✅ RESOLVED (11 CI iterations).** UTM.framework builds green + links. The wall was
   the app→framework ObjC↔Swift interop: a framework emits only the PUBLIC `<UTM/UTM-Swift.h>`,
   so every Swift `@objc` symbol UTM's own ObjC consumes had to be made `public`. Scoped the
   public-ification to the 6 ObjC-consumed interop files (broad passes cascaded onto unrelated
   pure-Swift classes). Tail: `UTMQemuPort`'s 8 `QEMUPort`/`CSPortDelegate` conformance members
   promoted to public. See `apply_fork.sh` §2b/§2c.
3. Runtime: `UTMLauncher.makeRootViewController()` presents `UTMSingleWindowView(data:)`; the
   `utm` switcher case + `UTMModeView` + bridging-header forward-decl are wired. VM storage
   isolation to `Documents/UTM/` — TODO (verify on device; UTMData defaults may already scope
   to Documents).
4. **Embed — ✅ wired (validating in main CI).** See "M4 packaging — RESOLVED" below.

## M4 packaging — RESOLVED (research + empirical sysroot probe)

- **Deps ship PRE-WRAPPED.** The ios-tci sysroot already contains `Frameworks/NAME.framework`
  (flat iOS layout, `LC_ID_DYLIB = @rpath/NAME.framework/NAME`), produced by UTM's
  `scripts/build_dependencies.sh` `fixup_all`. No dylib→framework wrapping in Xcode; `lib/*.dylib`
  are link-time only. 64 frameworks total (SE embeds 54; we bulk-copy all 64, a harmless superset).
- **UTM.framework is a monolith** — statically links QEMUKit/QEMUKitInternal/CocoaSpiceNoUsb +
  all SPM packages (only `.o`/`.swiftmodule` in Products, no sibling frameworks). Ships 3 SPM
  resource bundles (CocoaSpice, InAppSettingsKit, ZIPFoundation) nested in UTM.framework.
- **ASan was scheme-only.** `iOS-SE.xcscheme` LaunchAction had `enableAddressSanitizer="YES"`
  (Debug); `xcodebuild build -scheme` honoured it → `Objects-normal-asan` + a
  `libclang_rt.asan_ios_dynamic` load. Fix: flip the scheme flag in `apply_fork.sh` +
  `-enableAddressSanitizer NO`. The sysroot dylibs are NOT asan (verified).
- **Resource placement:** UTM reads firmware via `Bundle.main.url(forResource:"qemu")` → copies to
  `Caches/qemu` → QEMU `-L <caches>/qemu`; Vulkan ICDs via `VK_DRIVER_FILES=Bundle.main/vulkan/icd.d`.
  `Bundle.main` = OpenClaw once embedded, so CI puts `qemu/` + `vulkan/` at the **app bundle root**
  (no UTM code patch). Only `share/qemu` (316M firmware/ROMs/keymaps) + `share/vulkan` are needed;
  locale/doc/man dropped.
- **Embed mechanism:** project.yml link+embeds only `UTM.framework` (resolves the forward-declared
  `UTMLauncher`); the 63 `@rpath` deps are runtime-only (OpenClaw never references them), so CI
  bulk-copies them into `App.app/Frameworks/` post-archive and zsign deep-signs. UTM.framework's
  `@executable_path/Frameworks` rpath finds them; deps find each other via baked `@loader_path/..`.
- **Size:** Vendor/UTMPrebuilt ≈ 1.9 GB uncompressed (207 MB compressed). Trim opportunity: drop
  unused qemu arches (m68k/ppc/ppc64/riscv64 ≈ −800 MB) once a VM boots on device.

## Known runtime risks

- Size: ~200 MB of QEMU/deps added to OpenClaw (the app is already ~440 MB signed).
- UTM's process model: SE runs QEMU in-process (dlopen the qemu-*-softmmu dylib) rather than
  spawning QEMUHelper — good for embedding, but the in-process QEMU + its threads inside
  OpenClaw's process is the big runtime unknown.
- Metal/Vulkan (MoltenVK) display renderer inside a hosted UIViewController.
- Memory: full-system VMs are RAM-hungry; the increased-memory-limit entitlement (added for
  iSH) helps.

## Fork layout (planned, mirrors Modes/iSH)

```
Modes/UTM/
  fork/
    UTMLauncher.h/.m        # ObjC boundary OpenClaw calls
    apply_fork.sh           # CI: assemble sysroot from IPA, apply app-layer patches
    convert_to_framework.rb # UTM app target -> UTMSE.framework
    extract_sysroot.sh      # pull framework binaries out of UTM-SE.ipa into the sysroot
    UTMMode-Info.plist
```
