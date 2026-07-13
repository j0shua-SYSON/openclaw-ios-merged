#!/bin/bash
#
# apply_fork.sh <delta-clone-dir> <fork-dir>
#
# Applies the OpenClaw DeltaMode fork to a fresh Delta clone on CI. Everything it
# touches is inside the clone (which lives only on the runner) — nothing here
# writes to the OpenClaw repo or to any local F: path.
#
set -euo pipefail

CLONE="$1"                              # e.g. $PWD/delta
FORK="$2"                               # e.g. $PWD/openclaw/Modes/Delta/fork
APP="$CLONE/Delta"                      # Delta's app source dir

echo "== apply_fork: clone=$CLONE fork=$FORK =="

# 1. Drop in the public factory + the umbrella header.
cp "$FORK/../App/DeltaHost.swift" "$APP/DeltaHost.swift"
cp "$FORK/Delta-umbrella.h"       "$APP/Delta.h"
cp "$FORK/DeltaMode-Info.plist"   "$CLONE/DeltaMode-Info.plist"
echo "   copied DeltaHost.swift, Delta.h (umbrella), DeltaMode-Info.plist"

# 2. Neutralize the app entry point — @UIApplicationMain is illegal in a framework.
perl -0pi -e 's/\@UIApplicationMain/\/\/ \@UIApplicationMain (removed for DeltaMode framework build)/g' \
  "$APP/AppDelegate.swift"
echo "   neutralized @UIApplicationMain in AppDelegate.swift"

# 3. Convert the app target into DeltaMode.framework.
ruby "$FORK/convert_to_framework.rb" "$CLONE/Delta.xcodeproj"

# 4. Repoint the shared "Delta" scheme's app-target buildable to the framework
#    product. Target keeps its name "Delta" (so BlueprintName is unchanged); only
#    the produced file name changes from Delta.app to Delta.framework. macOS/BSD sed.
SCHEME="$CLONE/Delta.xcodeproj/xcshareddata/xcschemes/Delta.xcscheme"
if [ -f "$SCHEME" ]; then
  sed -i '' \
    -e 's/BuildableName = "Delta.app"/BuildableName = "Delta.framework"/g' \
    "$SCHEME"
  echo "   repointed Delta.xcscheme buildable -> Delta.framework"
fi

echo "== apply_fork: done =="
