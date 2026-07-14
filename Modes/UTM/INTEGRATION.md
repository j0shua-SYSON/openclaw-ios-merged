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

## The crux: the sysroot headers

The prebuilt IPA gives us the **libs** (the ~60 framework binaries) but **not the headers**.
UTM's app layer (`Services/`, QEMUKit, CocoaSpice, `CSMain`) compiles against the sysroot's
`include/` — glib.h, qapi/*, spice, etc. `build_utm.sh -s iOS-SE` expects a sysroot with
both. So the plan must **assemble a sysroot**: prebuilt framework binaries (from the IPA,
relaid into the sysroot's `lib/`+`Frameworks/` layout) + a matching `include/`. Getting a
coherent `include/` without compiling the deps is the open problem — options:
1. Header-install only: run the `make install` header steps of `build_dependencies.sh` (still
   builds most of glib/qemu to generate configured headers — partial slowness).
2. Pull headers from the pinned dep source (glib/qemu/spice tags UTM uses) + the generated
   config headers — fragile ABI matching.
3. Full sysroot build, cached (the from-source path we rejected for OOM/time) — fallback.
This is the first thing to prototype; it determines whether the prebuilt path is viable.

## Milestones (each a CI iteration on utm-mode)

0. ✅ Research: map UTM-SE.ipa, pick the prebuilt path. (this doc)
1. Sysroot assembly: extract the ~60 framework binaries from UTM-SE.ipa + resolve headers →
   a sysroot `build_utm.sh` accepts. **Highest-risk milestone.**
2. Build UTM's app layer (scheme `iOS-SE`) → convert the app target to `UTMSE.framework`
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
