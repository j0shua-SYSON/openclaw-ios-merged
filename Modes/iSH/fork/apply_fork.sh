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
