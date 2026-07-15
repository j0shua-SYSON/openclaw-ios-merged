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

# 2b. Fix the Swift-generated header import. UTM's ObjC uses the app-style quoted
#     `#import "UTM-Swift.h"`; in a framework the generated header is part of the module and
#     must be imported framework-style `<UTM/UTM-Swift.h>` or it's "file not found". Patch
#     every ObjC source in the UTM tree (not the sysroot).
find "$CLONE" -type f \( -name "*.m" -o -name "*.mm" \) -not -path "*/sysroot-*" \
  -exec perl -0pi -e 's{#import "UTM-Swift.h"}{#import <UTM/UTM-Swift.h>}g' {} +
echo "   rewrote #import \"UTM-Swift.h\" -> <UTM/UTM-Swift.h> in ObjC sources"

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
