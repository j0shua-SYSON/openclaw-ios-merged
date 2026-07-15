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
2. Build UTM's app layer (scheme `iOS-SE`) against the sysroot → convert the app target to `UTMSE.framework`
   (drop QEMUHelper/Remote/extensions; UTM SE already runs QEMU in-process via dlopen since
   iOS can't spawn processes). Neutralize `@main`.
3. Runtime: a `UTMLauncher` factory that presents UTM's root VM-list VC; isolate VM storage
   to `Documents/UTM/`; redirect `Bundle.main` resource lookups (firmware, spice bundle) to
   the framework bundle.
4. Embed: `UTMSE.framework` + all ~60 QEMU/dep frameworks + firmware in project.yml; wire the
   switcher (`utm` id already in the registry); entitlements; merge → OTA. Device-verify a VM boots.

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
