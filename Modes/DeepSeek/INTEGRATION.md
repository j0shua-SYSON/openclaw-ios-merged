# DeepSeek mode integration

## What this mode is

DeepSeek ships **no open source**. So — unlike every other mode — there is no upstream
app to fork into a framework. The mode is instead the **buildable reconstruction** of the
shipped DeepSeek 2.2.2 iOS client: a clean-room UIKit shell built *around* the binary
analysis, not the app itself.

Concretely, `DSRootViewController` is a `UISegmentedControl` over three tabs:

- **Chat** — an intentional *offline* stub. The network/model implementation is not present
  in the IPA and was not reconstructed; the tab says so rather than pretending otherwise.
- **Pseudocode** — the real feature: a searchable browser over the **6,006 recovered Ghidra
  function bodies** (by module / address / symbol), each viewable in full.
- **About** — per-module recovered-function counts.

The 6,006 bodies are compiled **into the binary** as raw-string data (the
`recovered_pseudocode` C++17 catalog); nothing is read from disk at runtime.

> An earlier plan here was a from-scratch *functional* guest client (reverse-engineer the
> `DeepSeekHashV1` guest PoW, hit `guest/chat/completion`). That was abandoned — the ask is
> to embed the buildable reconstruction that already exists in `deepseek_reverse`, not to
> build a live client. The PoW/recon scratch work is gitignored (`.work/`, `ghidra_proj/`).

## Why this is the simplest embed in the repo

`DeepSeekRebuilt` is pure UIKit **ObjC++/C++17** with:

- **No third-party dependencies** — only UIKit / Foundation / CoreGraphics (all system).
- **No Swift module** — so no transitive Swift/Clang module graph to keep out of OpenClaw.
- **No `Bundle.main` reads** — the catalog is compiled in, so §6.1 of the embedding handoff
  (the recurring `Bundle.main`-resolves-to-the-host bug class) simply does not apply. The
  only `Bundle`-ish token in the source is a string literal in the About copy.

Because of that, this mode is **not** a prebuilt/vendored framework built from a fork. It is
an **in-project XcodeGen framework target** (the `FoliumMode` pattern): it compiles during
the normal OpenClaw build. There is **no fork script, no CocoaPods, no CMake, no
`Vendor/*Prebuilt`, and no ios-build.yml prebuild/cache step.**

## Layout (vendored into the repo, SmartTube-style)

The source is vendored (there is no public pinned SHA to clone; the origin is the local
`deepseek_reverse/deepseek_buildable_reconstruction`):

```
Modes/DeepSeek/
  DeepSeek.yml                       # XcodeGen spec → DeepSeekMode.framework
  App/
    DSRootViewController.{h,mm}      # the reconstructed shell (vendored verbatim)
    DeepSeekLauncher.{h,m}           # NEW: OpenClaw's entry point
  catalog/
    include/recovered_catalog.hpp    # vendored
    src/recovered_catalog.cpp        # vendored
    generated/recovered_data_*.cpp   # vendored (62 TUs, ~11 MB, the recovered bodies)
  .work/ · ghidra_proj/              # gitignored recon scratch (not part of the build)
```

`main.m` and `DSAppDelegate` are **deliberately dropped** — a framework has no `@main` /
`UIApplicationMain` and must not create its own `UIWindow`. `DeepSeekLauncher.makeRootViewController`
reproduces what the app delegate did (wrap the root VC in a `UINavigationController` with
`prefersLargeTitles`, which the Pseudocode tab's push navigation needs) and returns it for
OpenClaw to present.

## Wiring (Stage B)

1. `Sources/OpenClaw-Bridging-Header.h` — forward-declare `DeepSeekLauncher` (not `import
   DeepSeekMode`, so the catalog's C++ `<string>/<vector>` never enter OpenClaw's module scan;
   the class resolves from the embedded framework at link time via the ObjC runtime).
2. `Sources/ModeSwitcher.swift` — `DeepSeekModeView` + `case "deepseek"` + a registry tile.
3. `project.yml` — `include: Modes/DeepSeek/DeepSeek.yml` and a `- target: DeepSeekMode /
   embed: true` dependency. Nothing in ios-build.yml.

## Build / validation

Stage A validates the framework alone (`.github/workflows/deepseek-build.yml`): xcodegen the
spec at repo root, build the `DeepSeekMode` scheme, and assert `otool -L` on the binary shows
**system libraries only** (UIKit/Foundation/CoreGraphics + libobjc/libc++/libSystem/
CoreFoundation) — the self-contained "Yattee-easy" case, nothing to embed. (The framework's
own `@rpath/DeepSeekMode.framework/DeepSeekMode` install name is expected and excluded from
that check.)

Then the mode rides the normal `ios-build.yml` → sign → OTA path; DeepSeekMode.framework is
embedded by Xcode via the project.yml target dependency.
