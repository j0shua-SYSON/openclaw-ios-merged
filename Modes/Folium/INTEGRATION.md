# Folium mode — integration notes

Embedding Folium (NDS · PS1 · GB/GBC · GBA) as the `folium` switcher mode.
Source of truth: `F:\JOSHUA_1st_2021\projects\Folium` (native Xcode project, SPM, Swift 6, iOS 18).

## Dependency graph (mapped from Folium.xcodeproj)

App target links:
- **SharedDependencies** — local SPM package (in Folium repo). Self-contained: source targets
  (cereal, cryptopp, eventbus, glib, httplib, libchdr, libslirp, magic_enum, miniz, stb) +
  binary xcframeworks fetched from GitHub at resolve time (lib_fmt, lib_sdl3, lib_teakra, FLAC, ogg) +
  remote deps PLzmaSDK, OpenSSL. → **vendor the package; CI fetches the binaries.**
- **AntiqueKit** — was `../AntiqueKit` (off-repo). Provides 7 kits: AntiqueKit, ColourKit,
  ConstraintKit, ExtensionsKit, FontKit, OnboardingKit, SettingsKit. Pure Swift, no external deps.
  → **VENDORED** at `Packages/AntiqueKit`.
- **TPCircularBuffer** — was `~/Downloads/TPCircularBuffer` (off-repo). C target `CTPCircularBuffer`.
  → **VENDORED** at `Packages/TPCircularBuffer` (from github.com/michaeltyson/TPCircularBuffer).
- **zstd** — remote (github.com/jarrodnorwell/zstd): libseekable_format, libzstd, libzstdwrapper.
  → CI fetches.

Core static libs (C/C++ in-tree, compiled by Xcode): **Grape** (NDS/melonDS), **Kiwi** (GB/GBC),
**Mandarine** (PS1), **Tomato** (GBA). **Cytrus** (3DS/Citra) is a stub — **dropped** (needs JIT+Vulkan).

## Status

- [x] Dependency graph mapped; off-repo deps obtained and vendored (`Packages/`).
- [ ] Vendor `SharedDependencies` + Folium app sources (`Folium/Folium/`) + 4 core source trees.
- [ ] Recreate build graph in OpenClaw `project.yml`: 4 core static-lib targets + a `FoliumMode`
      framework target (Swift + C++ interop, per-core header search paths, bridging headers) +
      package refs (SharedDependencies, AntiqueKit, TPCircularBuffer, zstd).
- [ ] Symbol isolation: build FoliumMode as a framework with hidden C/C++ symbols so its melonDS
      won't collide with Delta's (Phase 3).
- [ ] Redirect Folium data (per-core base URLs) → `Documents/Folium/`.
- [ ] Present `GamesController` (replicating SceneDelegate's bootstrap) as the `folium` mode,
      replacing the placeholder in `Sources/ModeSwitcher.swift`.
- [ ] CI green.

Nothing here is wired into `project.yml` yet, so it stays inert (build stays green) until the
FoliumMode target is added.
