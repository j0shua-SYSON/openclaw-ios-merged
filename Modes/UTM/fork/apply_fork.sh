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
# Promote only the Swift @objc symbols UTM's ObjC (the 7 files that import UTM-Swift.h)
# actually consumes — NOT every @objc class, because making an unrelated pure-Swift class
# public cascades access onto all its protocol conformances/overrides. These files are
# either extensions on ObjC/UIKit types (no class-public cascade) or the two small NSObject
# subclasses ObjC references directly (UTMPasteboard, UTMQemuPort). Guard preserves the
# @objc private dynamic swizzling in UTMPatches.swift.
for f in \
  Platform/iOS/Display/VMDisplayViewControllerDelegate.swift \
  Platform/iOS/Display/VMDisplayViewController.swift \
  Services/UTMPasteboard.swift \
  Services/UTMExtensions.swift \
  Platform/iOS/UTMPatches.swift \
  Services/UTMQemuPort.swift; do
  [ -f "$CLONE/$f" ] || continue
  perl -0pi -e 's/\@objc (?!(public|private|fileprivate|internal|open|@))/\@objc public /g' "$CLONE/$f"
  perl -0pi -e 's/(\@objc\([^)]*\)\r?\n\s*)(?!public |private |internal |fileprivate |open )(static |class |func |var |let |dynamic )/${1}public ${2}/g' "$CLONE/$f"
done

# 2c. Bounded protocol-conformance cascade. UTMQemuPort is an @objc NSObject subclass ObjC
#     references, so 2b makes the class public — but its members that satisfy the *public*
#     protocols QEMUPort / CSPortDelegate (readDataHandler, errorHandler, disconnectHandler,
#     isOpen, write, and the three CSPortDelegate port(...) methods) are neither @objc nor
#     access-keyworded, so they stay internal and Swift errors "must be declared public
#     because it matches a requirement in public protocol". They all sit at member-level
#     (4-space) indentation; the private stored props already carry `private`, so promote
#     every bare 4-space `var`/`func` in just this file. Closures are indented deeper (8+),
#     @objc init is handled by 2b — so this hits exactly the 8 conformance members.
QP="$CLONE/Services/UTMQemuPort.swift"
if [ -f "$QP" ]; then
  perl -0pi -e 's/^(    )(?!private|public|internal|fileprivate|open|\@)(var |func )/${1}public ${2}/mg' "$QP"
  echo "   promoted UTMQemuPort QEMUPort/CSPortDelegate conformance members to public"
fi
echo "   framework-style UTM-Swift.h import + targeted public @objc interop symbols"

# 3. Convert the iOS-SE app target -> UTM.framework.
ruby "$FORK/convert_to_framework.rb" "$CLONE/UTM.xcodeproj"

# 4. Repoint the iOS-SE scheme's buildable from "UTM SE.app" -> UTM.framework so
#    `xcodebuild -scheme iOS-SE` produces the framework. macOS/BSD sed.
SCHEME="$CLONE/UTM.xcodeproj/xcshareddata/xcschemes/iOS-SE.xcscheme"
if [ -f "$SCHEME" ]; then
  sed -i '' -e 's/BuildableName = "UTM SE.app"/BuildableName = "UTM.framework"/g' "$SCHEME"
  # UTM's iOS-SE scheme ships with AddressSanitizer on (enableAddressSanitizer = "YES").
  # `xcodebuild build -scheme iOS-SE` honours it, so the framework + its statically linked
  # QEMUKit/CocoaSpice objects get asan-instrumented and drag libclang_rt.asan_ios_dynamic.
  # Turn it (and UBSan, if present) off for the shippable embed. Also overridden on the
  # xcodebuild command line as a belt-and-suspenders.
  sed -i '' -e 's/enableAddressSanitizer = "YES"/enableAddressSanitizer = "NO"/g' \
             -e 's/enableUBSanitizer = "YES"/enableUBSanitizer = "NO"/g' "$SCHEME"
  echo "   repointed iOS-SE.xcscheme buildable -> UTM.framework; disabled scheme asan/ubsan"
fi

echo "== apply_fork(UTM): done =="
