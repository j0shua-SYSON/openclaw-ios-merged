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
