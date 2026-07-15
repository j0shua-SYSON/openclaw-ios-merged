#!/bin/bash
#
# apply_fork.sh <utm-clone-dir> <fork-dir>
#
# Applies the OpenClaw UTM SE mode fork to a fresh UTM clone on CI. Assumes the prebuilt
# sysroot has already been extracted to <utm-clone-dir>/sysroot-ios-tci-arm64. Everything
# it touches is inside the clone (runner-only); nothing writes to the OpenClaw repo.
#
set -euo pipefail

CLONE="$1"                 # e.g. $PWD/utm
FORK="$2"                  # e.g. $PWD/openclaw/Modes/UTM/fork

echo "== apply_fork(UTM): clone=$CLONE fork=$FORK =="

# 1. Drop in the launcher, the umbrella (replacing the bridging header), the framework plist.
cp "$FORK/UTMLauncher.swift"  "$CLONE/Platform/iOS/UTMLauncher.swift"
cp "$FORK/UTM-umbrella.h"     "$CLONE/UTM.h"
cp "$FORK/UTMMode-Info.plist" "$CLONE/UTMMode-Info.plist"
echo "   copied UTMLauncher.swift, UTM/UTM.h (umbrella), UTMMode-Info.plist"

# 2. Neutralize the app entry point — @main is illegal in a framework. Main.main() is
#    never called (we boot via UTMLauncher). CRLF-safe.
perl -0pi -e 's/\@main(\r?\n)(class Main)/\/\/ \@main (removed for UTM.framework)$1$2/' \
  "$CLONE/Platform/Main.swift"
grep -q "// @main (removed for UTM.framework)" "$CLONE/Platform/Main.swift" \
  || { echo "ERROR: @main neutralization did not apply"; exit 1; }
echo "   neutralized @main in Platform/Main.swift"

# 2b. Swift-generated-header interop. A framework only emits the PUBLIC <UTM/UTM-Swift.h>
#     (public @objc), so UTM's own ObjC must import it framework-style, and the Swift @objc
#     declarations that ObjC consumes must be public. Rewrite the imports, then promote the
#     small set of ObjC-consumed Swift symbols (only 7 ObjC files consume UTM-Swift.h).
find "$CLONE" -type f \( -name "*.m" -o -name "*.mm" \) -not -path "*/sysroot-*" \
  -exec perl -0pi -e 's{#import "UTM-Swift.h"}{#import <UTM/UTM-Swift.h>}g' {} +

# Promote the @objc Swift symbols that UTM's ObjC display/input controllers consume to
# public so they appear in the framework's public <UTM/UTM-Swift.h>. Guarded so decls that
# already carry an access keyword are untouched — critically, the @objc private dynamic
# swizzling patches in UTMPatches.swift stay private. Scoped to the known interop files.
# @objc signatures are ObjC-compatible by construction, so promoting every @objc decl in
# UTM's app-layer Swift to public is self-consistent (the @objc types become public
# together) and exposes the whole reverse-interop surface to the framework header at once.
# Scoped to UTM's own sources (not the QEMUKit/CocoaSpice submodule frameworks). The guard
# preserves the @objc private dynamic swizzling in UTMPatches.swift.
UI_SRC=""
for d in Services Platform Configuration Renderer Scripting Intents Remote; do
  [ -d "$CLONE/$d" ] && UI_SRC="$UI_SRC $CLONE/$d"
done
find $UI_SRC -type f -name "*.swift" 2>/dev/null | while read -r f; do
  perl -0pi -e 's/\@objc (?!(public|private|fileprivate|internal|open))/\@objc public /g' "$f"
  perl -0pi -e 's/(\@objc\([^)]*\)\r?\n\s*)(?!public |private |internal |fileprivate |open )(static |class |func |var |let |dynamic )/${1}public ${2}/g' "$f"
done
echo "   framework-style UTM-Swift.h import + broad public @objc across app-layer Swift"

# 3. Convert the iOS-SE app target -> UTM.framework.
ruby "$FORK/convert_to_framework.rb" "$CLONE/UTM.xcodeproj"

# 4. Repoint the iOS-SE scheme's buildable from "UTM SE.app" -> UTM.framework so
#    `xcodebuild -scheme iOS-SE` produces the framework. macOS/BSD sed.
SCHEME="$CLONE/UTM.xcodeproj/xcshareddata/xcschemes/iOS-SE.xcscheme"
if [ -f "$SCHEME" ]; then
  sed -i '' -e 's/BuildableName = "UTM SE.app"/BuildableName = "UTM.framework"/g' "$SCHEME"
  echo "   repointed iOS-SE.xcscheme buildable -> UTM.framework"
fi

echo "== apply_fork(UTM): done =="
