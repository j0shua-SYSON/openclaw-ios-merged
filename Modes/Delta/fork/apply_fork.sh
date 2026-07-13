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

# 1. Drop in the public factory, the ObjC boundary, and the umbrella header.
cp "$FORK/../App/DeltaHost.swift" "$APP/DeltaHost.swift"
cp "$FORK/DeltaLauncher.h"        "$APP/DeltaLauncher.h"
cp "$FORK/DeltaLauncher.m"        "$APP/DeltaLauncher.m"
cp "$FORK/Delta-umbrella.h"       "$APP/Delta.h"
cp "$FORK/DeltaMode-Info.plist"   "$CLONE/DeltaMode-Info.plist"
echo "   copied DeltaHost.swift, DeltaLauncher.{h,m}, Delta.h (umbrella), DeltaMode-Info.plist"

# 2. Neutralize the app entry point — @UIApplicationMain is illegal in a framework.
perl -0pi -e 's/\@UIApplicationMain/\/\/ \@UIApplicationMain (removed for DeltaMode framework build)/g' \
  "$APP/AppDelegate.swift"
echo "   neutralized @UIApplicationMain in AppDelegate.swift"

# 2b. Redirect Delta's own-resource lookups from Bundle.main (which is OpenClaw.app
#     when embedded) to the Delta.framework bundle. Delta bundles openvgdb.sqlite,
#     cheatbase.zip, WhatsNew/Patreon/RevenueCat/Contributors/CheatIcons/Lu plists,
#     Profanity.txt and nibs in the framework, but loads them via Bundle.main —
#     several force-unwrapped, so they crash on launch when embedded. Bundle
#     .deltaResources (defined in DeltaHost.swift) points at the framework bundle.
find "$APP" -name "*.swift" -type f -exec perl -0pi -e \
  's/Bundle\.main\.url\(forResource/Bundle.deltaResources.url(forResource/g;
   s/Bundle\.main\.path\(forResource/Bundle.deltaResources.path(forResource/g;
   s/Bundle\.main\.loadNibNamed\(/Bundle.deltaResources.loadNibNamed(/g' {} +
echo "   redirected Bundle.main resource lookups -> Bundle.deltaResources"

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
