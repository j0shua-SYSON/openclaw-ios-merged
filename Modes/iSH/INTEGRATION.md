# iSH mode integration

Embed [iSH](https://github.com/ish-app/ish) (`ish-app/ish`, GPLv3) as a hidden OpenClaw
mode: a JIT-less usermode x86/Linux (Alpine) shell that runs on stock iOS. This is the
**hardest** embed so far — closer to Delta + Feather combined — so it is staged in
milestones rather than one shot.

## Why it's hard (vs Folium/Delta/Feather)

Those were pure Xcode/Swift(+CocoaPods) app targets. iSH is:

1. **A C emulator built by meson+ninja *inside* the Xcode build.** The `iSH` app target
   depends on aggregate targets that run `app/xcode-meson.sh` / `app/xcode-ninja.sh` to
   compile `libish.a` (the `emu/ kernel/ fs/ linux/ asbestos/` sources). CI must have
   `meson` + `ninja` (brew) and the `deps/` submodules.
2. **Submodules:** `deps/libapps` (hterm terminal JS → the WKWebView UI), `deps/libarchive`
   (extract the Alpine rootfs tar), `deps/linux` (`update=none, shallow` — headers only,
   used by the `+Linux` variant which we do NOT build).
3. **A booted "kernel."** `AppDelegate -boot` (app/AppDelegate.m:74) does
   `mount_root(&fakefs, <root>/data)`, wires devices, sets DNS, then `task_start(current)`
   to spawn Alpine's init with `UserPreferences.shared.bootCommand`. The terminal only works
   after this boots. Normally driven by `application:willFinishLaunching`.
4. **A root filesystem.** `Roots.m` keeps roots under `ContainerURL()/roots`; the first root
   is created by extracting a bundled Alpine tar on first launch.

## Build graph (from iSH.xcodeproj)

- Schemes: `iSH` (what we build), `iSH+Linux` (skip — needs deps/linux kernel), `ish-cli`, `Screenshots`.
- App target: `iSH` (product-type application) → links `libiSHApp.a` (ObjC app code in `app/`),
  `libish.a` (meson-built C emulator), `libarchive.a`.
- Aggregate/script targets: `Meson`, `Ninja` (build the emulator), `libiSHApp`, `libish`, `libarchive`.
- Extension: `iSHFileProvider` (Files.app integration) — **dropped** for the embed.
- Entry: `app/main.m` → `UIApplicationMain(... AppDelegate)`. Root VC = `TerminalViewController`
  from `Terminal.storyboard` (Info.plist `UIMainStoryboardFile = Terminal`).

## Decisions (sensible defaults; revisit if the user wants)

- **Drop `iSHFileProvider`.** It exists only for Files.app browsing of the rootfs and needs an
  app-group entitlement shared between app+extension. Without it, `AppGroup.ContainerURL()`
  falls back to the app data container — fine for an embedded mode. Loses Files.app integration only.
- **Bundle a prebuilt Alpine rootfs** inside iSH.framework (fetched at CI build time, same source
  iSH uses) rather than download-on-first-launch, so the mode works offline like the others.
- **Isolate storage** to `Documents/iSH/` — redirect `ContainerURL()` so `roots/` and all state
  live in an iSH-only subdir, not OpenClaw's container root.
- **Entitlement:** add `com.apple.developer.kernel.increased-memory-limit` to OpenClaw (the emulator
  wants headroom). `com.apple.developer.user-fonts` (app-usage) is optional (iSH font import) — skip.
- **Kernel boot moves to the host factory.** `iSHHost.makeRootViewController` runs the `-boot`
  sequence (once, guarded) then returns the `TerminalViewController` from Terminal.storyboard loaded
  from the framework bundle.

## Milestones

1. **Builds green in CI as `iSH.framework`.** Clone + submodules, brew meson/ninja, apply fork
   (convert `iSH` app target → framework, neutralize `@UIApplicationMain`/`main.m`, keep the meson
   build phases + static-lib links), archive `iSH.framework` + deps into `Vendor/iSHPrebuilt`.
2. **Boots embedded.** `iSHHost` runs the mount_root + task_start boot with the rootfs redirected to
   `Documents/iSH/roots`; present `TerminalViewController`. Redirect `Bundle.main` resource lookups
   (Terminal.storyboard, hterm assets, Alpine tar) → the framework bundle.
3. **Wire the switcher.** `iSHLauncher` ObjC shim in the bridging header; `iSHModeView` in
   ModeSwitcher; embed `iSH.framework` (+ libarchive if dynamic) in project.yml; increased-memory
   entitlement.

## Known runtime risks to discover via CI/device

- Kernel `pthreads` + signal setup running inside OpenClaw's process (not the main app).
- `AppGroup.ContainerURL()` fallback path when OpenClaw lacks the iSH app-group.
- hterm WKWebView loading its JS/HTML from the framework bundle (not Bundle.main).
- Scene-based lifecycle (`SceneDelegate`) vs. our present-a-VC embedding — bypass the scene delegate.

## Fork layout (mirrors Modes/Delta, Modes/Feather)

```
Modes/iSH/
  App/iSHHost.m            # @objc factory: boot kernel + return TerminalViewController
  fork/
    iSHLauncher.h/.m       # pure-ObjC boundary OpenClaw calls (no Swift module import needed; iSH is ObjC)
    apply_fork.sh          # CI: drop in host+launcher, neutralize main.m, redirect Bundle.main + ContainerURL
    convert_to_framework.rb# xcodeproj: iSH app target → framework, drop FileProvider, keep meson/link phases
    iSHMode-Info.plist
```
