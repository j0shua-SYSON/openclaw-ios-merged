#!/bin/bash
#
# apply_fork.sh <feather-clone-dir> <fork-dir>
#
# Applies the OpenClaw FeatherMode fork to a fresh Feather clone on CI. Everything
# it touches is inside the clone (runner-only) — nothing writes to the OpenClaw repo
# or any local F: path. Mirrors Modes/Delta/fork/apply_fork.sh.
#
set -euo pipefail

CLONE="$1"                              # e.g. $PWD/feather
FORK="$2"                               # e.g. $PWD/openclaw/Modes/Feather/fork
APP="$CLONE/Feather"                    # Feather's app source dir

echo "== apply_fork(feather): clone=$CLONE fork=$FORK =="

# 1. Drop in the factory, the ObjC boundary, umbrella, framework plist, and the
#    data-isolation overlay.
cp "$FORK/../App/FeatherHost.swift"       "$APP/FeatherHost.swift"
cp "$FORK/FeatherLauncher.h"              "$APP/FeatherLauncher.h"
cp "$FORK/FeatherLauncher.m"              "$APP/FeatherLauncher.m"
cp "$FORK/Feather-umbrella.h"            "$APP/Feather.h"
cp "$FORK/FeatherMode-Info.plist"        "$CLONE/FeatherMode-Info.plist"
cp "$FORK/FileManager+documents.swift"   "$APP/Extensions/FileManager+documents.swift"
echo "   copied FeatherHost.swift, FeatherLauncher.{h,m}, Feather.h, Info.plist, FileManager+documents.swift"

# 2. Neutralize the SwiftUI app entry — @main is illegal in a framework.
perl -0pi -e 's/^\@main/\/\/ \@main (removed for FeatherMode framework)/m' "$APP/FeatherApp.swift"
echo "   neutralized @main in FeatherApp.swift"

# 3. Remove the `static` forward declaration from iconPoc.h — a static function
#    decl in a modular umbrella header is rejected/warns. (Unused POC helper; its
#    definition, if any, stays self-contained in iconPoc.m.)
perl -0pi -e 's/^\s*static\s+CGColorRef\s+FRCreateCGColorFromHex\(void\);\s*$//m' "$APP/Utilities/iconPoc.h"
echo "   stripped static FRCreateCGColorFromHex decl from iconPoc.h"

# 4. Isolate Core Data: point the store at Documents/Feather/Feather.sqlite.
perl -0pi -e 's/(container = NSPersistentContainer\(name: _name\)\n)/$1\n\t\tif !inMemory {\n\t\t\tlet _dir = URL.documentsDirectory.appendingPathComponent("Feather", isDirectory: true)\n\t\t\ttry? FileManager.default.createDirectory(at: _dir, withIntermediateDirectories: true)\n\t\t\tcontainer.persistentStoreDescriptions.first?.url = _dir.appendingPathComponent("Feather.sqlite")\n\t\t}\n/' \
  "$APP/Backend/Storage/Storage.swift"
echo "   redirected Core Data store -> Documents/Feather/Feather.sqlite"

# 5. Convert the app target into Feather.framework.
ruby "$FORK/convert_to_framework.rb" "$CLONE/Feather.xcodeproj"

# 6. Repoint the shared "Feather" scheme's buildable to the framework product.
SCHEME="$CLONE/Feather.xcodeproj/xcshareddata/xcschemes/Feather.xcscheme"
if [ -f "$SCHEME" ]; then
  sed -i '' -e 's/BuildableName = "Feather.app"/BuildableName = "Feather.framework"/g' "$SCHEME"
  echo "   repointed Feather.xcscheme buildable -> Feather.framework"
fi

echo "== apply_fork(feather): done =="
