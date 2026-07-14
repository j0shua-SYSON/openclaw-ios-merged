#!/bin/bash
#
# apply_fork.sh <ish-clone-dir> <fork-dir>
#
# Applies the OpenClaw iSH mode fork to a fresh iSH clone on CI. Everything it touches
# is inside the clone (which lives only on the runner) — nothing writes to the OpenClaw
# repo or any local F: path.
#
set -euo pipefail

CLONE="$1"                 # e.g. $PWD/ish
FORK="$2"                  # e.g. $PWD/openclaw/Modes/iSH/fork
APP="$CLONE/app"           # iSH's app source dir

echo "== apply_fork(iSH): clone=$CLONE fork=$FORK =="

# 1. Drop in the ObjC boundary + the framework Info.plist.
cp "$FORK/iSHLauncher.h"     "$APP/iSHLauncher.h"
cp "$FORK/iSHLauncher.m"     "$APP/iSHLauncher.m"
cp "$FORK/iSHMode-Info.plist" "$CLONE/iSHMode-Info.plist"
echo "   copied iSHLauncher.{h,m}, iSHMode-Info.plist"

# 2. Neutralize the app entry point. main.m lives in libiSHApp.a, and iSH links ObjC
#    static libs with -ObjC / -all_load (to pull in categories), which would drag the
#    `main` symbol into iSH.framework and collide with OpenClaw's own `main`. iSH is
#    booted via iSHLauncher, so its main() is never called — rename it away.
perl -0pi -e 's/\bint\s+main\s*\(/int ish_disabled_main(/g' "$APP/main.m"
echo "   neutralized main() in app/main.m"

# 2b. AppGroup.m reads the host's own entitlements via &_mh_execute_header to locate
#     its app-group container. `_mh_execute_header` is defined only in an *executable*;
#     linked into a framework it is undefined ("Undefined symbols: __mh_execute_header")
#     and fails the link. Use the main image's header via dyld instead — image index 0
#     is always the main executable (OpenClaw when embedded), so this reads the host
#     app's entitlements, exactly what AppGroup wants. OpenClaw carries no iSH app-group,
#     so ContainerURL() falls back to the app data container (rootfs isolation to
#     Documents/iSH is handled separately in milestone 2).
perl -0pi -e 's{#import <mach-o/ldsyms.h>}{#import <mach-o/ldsyms.h>\n#import <mach-o/dyld.h>};
              s{&_mh_execute_header}{(const struct mach_header_64 *)_dyld_get_image_header(0)}g' \
  "$APP/AppGroup.m"
grep -q "_dyld_get_image_header(0)" "$APP/AppGroup.m" \
  || { echo "ERROR: AppGroup.m _mh_execute_header patch did not apply"; exit 1; }
echo "   patched AppGroup.m to read the host image header via dyld (framework-safe)"

# 2c. Redirect iSH's Bundle.main resource + storyboard lookups to the framework bundle.
#     Embedded, Bundle.main is OpenClaw, which has none of iSH's resources. iSHLauncher
#     lives in iSH.framework, so bundleForClass:iSHLauncher resolves to the framework
#     bundle. Covers root.tar.gz (rootfs), term.html (terminal), repositories.txt (apk
#     repos), alt icons, and the About storyboard.
perl -0pi -e 's/\[NSBundle\.mainBundle URLForResource:/[[NSBundle bundleForClass:NSClassFromString(\@"iSHLauncher")] URLForResource:/g' \
  "$APP/Roots.m" "$APP/Terminal.m" "$APP/CurrentRoot.m" "$APP/AltIconViewController.m"
perl -0pi -e 's/storyboardWithName:\@"About" bundle:nil/storyboardWithName:\@"About" bundle:[NSBundle bundleForClass:NSClassFromString(\@"iSHLauncher")]/g' \
  "$APP/AppDelegate.m" "$APP/SceneDelegate.m" "$APP/TerminalViewController.m"
grep -q 'bundleForClass:NSClassFromString(@"iSHLauncher")] URLForResource:@"root"' "$APP/Roots.m" \
  || { echo "ERROR: Roots.m rootfs bundle redirect did not apply"; exit 1; }
grep -q 'bundleForClass:NSClassFromString(@"iSHLauncher")] URLForResource:@"term"' "$APP/Terminal.m" \
  || { echo "ERROR: Terminal.m term.html bundle redirect did not apply"; exit 1; }
echo "   redirected Bundle.main resource + About-storyboard lookups -> framework bundle"

# 2d. Isolate iSH's storage. ContainerURL() returns the app-group container (nil for
#     OpenClaw, which has no iSH app-group). Point it at Documents/iSH so the rootfs and
#     all iSH state live in an iSH-only subdir of OpenClaw's container.
perl -0pi -e 's/NSURL \*ContainerURL\(void\) \{.*?\n\}/NSURL *ContainerURL(void) {\n    NSURL *docs = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;\n    NSURL *base = [docs URLByAppendingPathComponent:\@"iSH" isDirectory:YES];\n    [NSFileManager.defaultManager createDirectoryAtURL:base withIntermediateDirectories:YES attributes:nil error:nil];\n    return base;\n}/s' \
  "$APP/AppGroup.m"
grep -q 'URLByAppendingPathComponent:@"iSH" isDirectory:YES' "$APP/AppGroup.m" \
  || { echo "ERROR: ContainerURL() isolation patch did not apply"; exit 1; }
echo "   isolated iSH storage to Documents/iSH via ContainerURL()"

# 3. Convert the iSH app target -> iSH.framework (drops FileProvider, adds launcher).
ruby "$FORK/convert_to_framework.rb" "$CLONE/iSH.xcodeproj"

# 4. Repoint the shared "iSH" scheme's buildable from iSH.app -> iSH.framework so
#    `xcodebuild -scheme iSH` produces the framework. macOS/BSD sed.
SCHEME="$CLONE/iSH.xcodeproj/xcshareddata/xcschemes/iSH.xcscheme"
if [ -f "$SCHEME" ]; then
  sed -i '' -e 's/BuildableName = "iSH.app"/BuildableName = "iSH.framework"/g' "$SCHEME"
  echo "   repointed iSH.xcscheme buildable -> iSH.framework"
fi

echo "== apply_fork(iSH): done =="
